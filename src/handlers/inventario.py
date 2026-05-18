import os
import logging
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
from auth import check_role_access
from http_utils import build_response, error_response, parse_json_body, resolve_table_name
from tenant_utils import resolve_tenant_id, item_belongs_to_tenant


dynamodb_endpoint = os.getenv('AWS_ENDPOINT_URL_DYNAMODB')
if not dynamodb_endpoint and os.getenv('AWS_SAM_LOCAL', 'false').lower() == 'true':
    dynamodb_endpoint = 'http://host.docker.internal:8000'
dynamodb = boto3.resource('dynamodb', endpoint_url=dynamodb_endpoint) if dynamodb_endpoint else boto3.resource('dynamodb')
productos_table_name = resolve_table_name(os.getenv('PRODUCTOS_TABLE'), 'productos')
inventario_table_name = resolve_table_name(os.getenv('INVENTARIO_TABLE'), 'inventario')
productos_table = dynamodb.Table(productos_table_name)
inventario_table = dynamodb.Table(inventario_table_name)
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


def lambda_handler(event, context):
    try:
        http_method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod')
        path = event.get('rawPath') or event.get('path') or ''
        path = path.rstrip('/') if path != '/' else path
        query_params = event.get('queryStringParameters') or {}
        body = event.get('body', '{}')

        if http_method == 'OPTIONS':
            return response(200, {'mensaje': 'ok'})

        try:
            body_data = parse_json_body(body)
        except ValueError as exc:
            return error_response(400, str(exc))

        tenant_id, tenant_error = resolve_tenant_id(event)
        if tenant_error:
            return error_response(400, tenant_error)

        if http_method == 'GET' and path == '/inventario':
            return listar_inventario(tenant_id)
        elif http_method == 'GET' and path == '/inventario/movimientos':
            return listar_movimientos(tenant_id)
        elif http_method == 'GET' and path == '/inventario/alertas':
            return alertas_stock_bajo(query_params, tenant_id)
        elif http_method == 'POST' and path in ['/inventario/movimiento', '/inventario/movimientos']:
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            return registrar_movimiento(body_data, tenant_id)
        elif http_method == 'GET' and path.startswith('/inventario/'):
            producto_id = path.split('/')[-1]
            return ver_stock_producto(producto_id, tenant_id)
        else:
            return error_response(404, 'Ruta no encontrada')

    except Exception:
        logger.exception('Error general inventario')
        return error_response(500, 'Error interno del servidor')


def listar_inventario(tenant_id):
    """
    GET /inventario
    Devuelve el stock actual de todos los productos.
    """
    try:
        resultado = productos_table.scan(Limit=200)
        productos = to_json_safe(resultado.get('Items', []))
        productos = [p for p in productos if item_belongs_to_tenant(p, tenant_id)]

        inventario = []
        for p in productos:
            inventario.append({
                'productoId': p.get('id'),
                'nombre': p.get('nombre', ''),
                'categoria': p.get('categoria', ''),
                'stock': p.get('stock', 0),
                'precio': p.get('precio', 0),
                'fechaActualizacion': p.get('fechaActualizacion')
            })

        return response(200, {
            'total': len(inventario),
            'inventario': inventario
        })

    except Exception:
        logger.exception('Error al listar inventario')
        return response(500, {'error': 'Error al listar inventario'})


def ver_stock_producto(producto_id, tenant_id):
    """
    GET /inventario/{productoId}
    Devuelve stock y datos basicos de un producto.
    """
    try:
        resultado = productos_table.get_item(Key={'id': producto_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        producto = to_json_safe(resultado['Item'])

        return response(200, {
            'productoId': producto.get('id'),
            'nombre': producto.get('nombre', ''),
            'stock': producto.get('stock', 0),
            'categoria': producto.get('categoria', ''),
            'fechaActualizacion': producto.get('fechaActualizacion')
        })

    except Exception:
        logger.exception('Error al obtener stock de producto')
        return response(500, {'error': 'Error al obtener stock del producto'})


def registrar_movimiento(data, tenant_id):
    """
    POST /inventario/movimiento

    Body esperado:
    {
      "productoId": "uuid",
      "tipo": "entrada|salida",
      "cantidad": number,
      "motivo": "string",
      "usuario": "string"
    }
    """
    try:
        requeridos = ['productoId', 'tipo', 'cantidad']
        for campo in requeridos:
            if campo not in data or data[campo] in [None, '']:
                return response(400, {'error': f'Campo requerido: {campo}'})

        producto_id = data['productoId']
        tipo = str(data['tipo']).lower()

        if tipo not in ['entrada', 'salida']:
            return response(400, {'error': 'El campo tipo debe ser entrada o salida'})

        try:
            cantidad = int(data['cantidad'])
        except Exception:
            return response(400, {'error': 'Cantidad invalida'})

        if cantidad <= 0:
            return response(400, {'error': 'La cantidad debe ser mayor a 0'})

        producto_result = productos_table.get_item(Key={'id': producto_id})
        if 'Item' not in producto_result:
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        if not item_belongs_to_tenant(producto_result['Item'], tenant_id):
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        producto = to_json_safe(producto_result['Item'])
        stock_anterior = int(producto.get('stock', 0))

        if tipo == 'salida' and cantidad > stock_anterior:
            return response(400, {
                'error': 'Stock insuficiente para realizar la salida',
                'stockDisponible': stock_anterior
            })

        stock_nuevo = stock_anterior + cantidad if tipo == 'entrada' else stock_anterior - cantidad
        ahora = datetime.utcnow().isoformat()

        productos_table.update_item(
            Key={'id': producto_id},
            UpdateExpression='SET stock = :stock, fechaActualizacion = :fecha',
            ExpressionAttributeValues={
                ':stock': stock_nuevo,
                ':fecha': ahora
            }
        )

        movimiento = {
            'id': str(uuid.uuid4()),
            'tenantId': tenant_id,
            'productoId': producto_id,
            'tipo': tipo,
            'cantidad': cantidad,
            'motivo': data.get('motivo', 'Sin motivo especificado'),
            'stockAnterior': stock_anterior,
            'stockNuevo': stock_nuevo,
            'fecha': ahora,
            'usuario': data.get('usuario', 'sistema')
        }

        inventario_table.put_item(Item=movimiento)

        return response(201, {
            'mensaje': 'Movimiento de inventario registrado exitosamente',
            'movimiento': movimiento
        })

    except Exception:
        logger.exception('Error al registrar movimiento')
        return response(500, {'error': 'Error al registrar movimiento de inventario'})


def listar_movimientos(tenant_id):
    """
    GET /inventario/movimientos
    Devuelve historial de movimientos.
    """
    try:
        resultado = inventario_table.scan(Limit=200)
        movimientos = to_json_safe(resultado.get('Items', []))
        movimientos = [m for m in movimientos if item_belongs_to_tenant(m, tenant_id)]
        movimientos = sorted(movimientos, key=lambda x: x.get('fecha', ''), reverse=True)

        return response(200, {
            'total': len(movimientos),
            'movimientos': movimientos
        })

    except Exception:
        logger.exception('Error al listar movimientos')
        return response(500, {'error': 'Error al listar movimientos'})


def alertas_stock_bajo(query_params, tenant_id):
    """
    GET /inventario/alertas?minStock=5
    Lista productos con stock bajo.
    """
    try:
        min_stock = int(query_params.get('minStock', 5))

        resultado = productos_table.scan(Limit=200)
        productos = to_json_safe(resultado.get('Items', []))
        productos = [p for p in productos if item_belongs_to_tenant(p, tenant_id)]

        alertas = []
        for p in productos:
            stock = int(p.get('stock', 0))
            if stock <= min_stock:
                alertas.append({
                    'productoId': p.get('id'),
                    'nombre': p.get('nombre', ''),
                    'stock': stock,
                    'stockMinimo': min_stock,
                    'categoria': p.get('categoria', '')
                })

        return response(200, {
            'totalAlertas': len(alertas),
            'stockMinimo': min_stock,
            'alertas': alertas
        })

    except Exception:
        logger.exception('Error al generar alertas de stock')
        return response(500, {'error': 'Error al generar alertas de inventario'})


def response(status_code, body):
    return build_response(status_code, body)
