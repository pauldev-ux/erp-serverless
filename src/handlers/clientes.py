import os
import logging
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
from auth import check_role_access
from http_utils import build_response, error_response, parse_json_body, resolve_table_name
from tenant_utils import resolve_tenant_id, item_belongs_to_tenant

# Inicializar cliente DynamoDB

dynamodb_endpoint = os.getenv('AWS_ENDPOINT_URL_DYNAMODB')
if not dynamodb_endpoint and os.getenv('AWS_SAM_LOCAL', 'false').lower() == 'true':
    dynamodb_endpoint = 'http://host.docker.internal:8000'
dynamodb = boto3.resource('dynamodb', endpoint_url=dynamodb_endpoint) if dynamodb_endpoint else boto3.resource('dynamodb')
clientes_table_name = resolve_table_name(os.getenv('CLIENTES_TABLE'), 'clientes')
table = dynamodb.Table(clientes_table_name)
logger = logging.getLogger(__name__)
logger.setLevel(os.getenv('LOG_LEVEL', 'INFO').upper())


def to_json_safe(value):
    if isinstance(value, list):
        return [to_json_safe(v) for v in value]
    if isinstance(value, dict):
        return {k: to_json_safe(v) for k, v in value.items()}
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    return value


def is_valid_email(email):
    # Validacion simple para entorno academico.
    return isinstance(email, str) and "@" in email and "." in email.split("@")[-1]


def lambda_handler(event, context):
    try:
        http_method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod')
        path = event.get('rawPath') or event.get('path') or ''
        path = path.rstrip('/') if path != '/' else path
        body = event.get('body', '{}')

        if http_method == 'OPTIONS':
            return build_response(200, {'mensaje': 'ok'})

        try:
            body_data = parse_json_body(body)
        except ValueError as exc:
            return error_response(400, str(exc))

        tenant_id, tenant_error = resolve_tenant_id(event)
        if tenant_error:
            return error_response(400, tenant_error)

        if http_method == 'POST' and path == '/clientes':
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            return crear_cliente(body_data, tenant_id)
        elif http_method == 'GET' and path == '/clientes':
            return listar_clientes(tenant_id)
        elif http_method == 'GET' and '/clientes/' in path:
            cliente_id = path.split('/')[-1]
            return obtener_cliente(cliente_id, tenant_id)
        elif http_method == 'PUT' and '/clientes/' in path:
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            cliente_id = path.split('/')[-1]
            return actualizar_cliente(cliente_id, body_data, tenant_id)
        elif http_method == 'DELETE' and '/clientes/' in path:
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            cliente_id = path.split('/')[-1]
            return eliminar_cliente(cliente_id, tenant_id)
        else:
            return error_response(404, 'Ruta no encontrada')

    except Exception:
        logger.exception('Error general clientes')
        return error_response(500, 'Error interno del servidor')


def crear_cliente(data, tenant_id):
    try:
        campos_requeridos = ['nombre', 'email', 'telefono']
        for campo in campos_requeridos:
            if campo not in data or not data[campo]:
                return error_response(400, f'Campo requerido: {campo}')

        if not is_valid_email(data.get('email')):
            return error_response(400, 'Email invalido')

        cliente_id = str(uuid.uuid4())
        ahora = datetime.utcnow().isoformat()

        cliente = {
            'id': cliente_id,
            'tenantId': tenant_id,
            'nombre': data.get('nombre'),
            'email': data.get('email'),
            'telefono': str(data.get('telefono')),
            'direccion': data.get('direccion', ''),
            'rfc': data.get('rfc', ''),
            'fechaRegistro': ahora,
            'fechaActualizacion': ahora
        }

        table.put_item(Item=cliente)

        return build_response(201, {
            'ok': True,
            'mensaje': 'Cliente creado exitosamente',
            'cliente': cliente
        })

    except Exception:
        logger.exception('Error al crear cliente')
        return error_response(500, 'Error al crear cliente')


def listar_clientes(tenant_id):
    try:
        response_obj = table.scan(Limit=100)
        clientes = to_json_safe(response_obj.get('Items', []))
        clientes = [c for c in clientes if item_belongs_to_tenant(c, tenant_id)]

        return build_response(200, {
            'ok': True,
            'total': len(clientes),
            'clientes': clientes
        })

    except Exception:
        logger.exception('Error al listar clientes')
        return error_response(500, 'Error al listar clientes')


def obtener_cliente(cliente_id, tenant_id):
    try:
        resultado = table.get_item(Key={'id': cliente_id})
        if 'Item' not in resultado:
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        cliente = to_json_safe(resultado['Item'])
        return build_response(200, {'ok': True, 'cliente': cliente})

    except Exception:
        logger.exception('Error al obtener cliente')
        return error_response(500, 'Error al obtener cliente')


def actualizar_cliente(cliente_id, data, tenant_id):
    try:
        resultado = table.get_item(Key={'id': cliente_id})
        if 'Item' not in resultado:
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        campos_actualizables = ['nombre', 'email', 'telefono', 'direccion', 'rfc']
        expresion_actualizar = 'SET fechaActualizacion = :ahora'
        valores = {':ahora': datetime.utcnow().isoformat()}

        for campo in campos_actualizables:
            if campo in data:
                if campo == 'email' and not is_valid_email(data[campo]):
                    return error_response(400, 'Email invalido')
                valores[f':{campo}'] = str(data[campo]) if campo == 'telefono' else data[campo]
                expresion_actualizar += f', {campo} = :{campo}'

        cliente_actualizado = table.update_item(
            Key={'id': cliente_id},
            UpdateExpression=expresion_actualizar,
            ExpressionAttributeValues=valores,
            ReturnValues='ALL_NEW'
        )

        cliente = to_json_safe(cliente_actualizado['Attributes'])

        return build_response(200, {
            'ok': True,
            'mensaje': 'Cliente actualizado exitosamente',
            'cliente': cliente
        })

    except Exception:
        logger.exception('Error al actualizar cliente')
        return error_response(500, 'Error al actualizar cliente')


def eliminar_cliente(cliente_id, tenant_id):
    try:
        resultado = table.get_item(Key={'id': cliente_id})
        if 'Item' not in resultado:
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return error_response(404, f'Cliente {cliente_id} no encontrado')

        table.delete_item(Key={'id': cliente_id})

        return build_response(200, {'ok': True, 'mensaje': f'Cliente {cliente_id} eliminado exitosamente'})

    except Exception:
        logger.exception('Error al eliminar cliente')
        return error_response(500, 'Error al eliminar cliente')
