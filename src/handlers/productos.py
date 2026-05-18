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
productos_table_name = resolve_table_name(os.getenv('PRODUCTOS_TABLE'), 'productos')
table = dynamodb.Table(productos_table_name)
logger = logging.getLogger(__name__)
logger.setLevel(os.getenv('LOG_LEVEL', 'INFO').upper())


def to_json_safe(value):
    """
    Convierte recursivamente valores Decimal de DynamoDB a tipos nativos de Python
    para que json.dumps no falle.
    """
    if isinstance(value, list):
        return [to_json_safe(v) for v in value]
    if isinstance(value, dict):
        return {k: to_json_safe(v) for k, v in value.items()}
    if isinstance(value, Decimal):
        # Si no tiene parte decimal, devolver int; en caso contrario, float.
        return int(value) if value % 1 == 0 else float(value)
    return value


def lambda_handler(event, context):
    """
    Manejador principal para todas las operaciones de productos.
    Rutea GET, POST, PUT, DELETE según el método HTTP.
    """
    try:
        # Soporta eventos API Gateway v1 (httpMethod/path) y v2 (requestContext.http/rawPath)
        http_method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod')
        path = event.get('rawPath') or event.get('path') or ''
        path = path.rstrip('/') if path != '/' else path
        body = event.get('body', '{}')

        if http_method == 'OPTIONS':
            return response(200, {'mensaje': 'ok'})
        
        # Parsear body si existe
        try:
            body_data = parse_json_body(body)
        except ValueError as exc:
            return error_response(400, str(exc))

        tenant_id, tenant_error = resolve_tenant_id(event)
        if tenant_error:
            return error_response(400, tenant_error)
        
        # Ruteo según método HTTP
        if http_method == 'POST' and path == '/productos':
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            return crear_producto(body_data, tenant_id)
        
        elif http_method == 'GET' and path == '/productos':
            return listar_productos(tenant_id)
        
        elif http_method == 'GET' and '/productos/' in path:
            producto_id = path.split('/')[-1]
            return obtener_producto(producto_id, tenant_id)
        
        elif http_method == 'PUT' and '/productos/' in path:
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            producto_id = path.split('/')[-1]
            return actualizar_producto(producto_id, body_data, tenant_id)
        
        elif http_method == 'DELETE' and '/productos/' in path:
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            producto_id = path.split('/')[-1]
            return eliminar_producto(producto_id, tenant_id)
        
        else:
            return error_response(404, 'Ruta no encontrada')
    
    except Exception:
        logger.exception('Error general en productos')
        return error_response(500, 'Error interno del servidor')


def crear_producto(data, tenant_id):
    """
    POST /productos
    Crear un nuevo producto.
    
    Body esperado:
    {
        "nombre": "string",
        "descripcion": "string",
        "precio": number,
        "stock": number,
        "categoria": "string"
    }
    """
    try:
        # Validar campos requeridos
        campos_requeridos = ['nombre', 'precio', 'stock']
        for campo in campos_requeridos:
            if campo not in data or data[campo] is None:
                return response(400, {'error': f'Campo requerido: {campo}'})
        
        # Generar ID único
        producto_id = str(uuid.uuid4())
        ahora = datetime.utcnow().isoformat()
        
        # Crear item
        producto = {
            'id': producto_id,
            'tenantId': tenant_id,
            'nombre': data.get('nombre'),
            'descripcion': data.get('descripcion', ''),
            'precio': Decimal(str(data.get('precio'))),
            'stock': int(data.get('stock')),
            'categoria': data.get('categoria', 'Sin categoría'),
            'fechaCreacion': ahora,
            'fechaActualizacion': ahora
        }
        
        # Guardar en DynamoDB
        table.put_item(Item=producto)
        
        # Convertir Decimals para JSON
        producto['precio'] = float(producto['precio'])
        
        return response(201, {
            'mensaje': 'Producto creado exitosamente',
            'producto': producto
        })
    
    except Exception:
        logger.exception('Error al crear producto')
        return response(500, {'error': 'Error al crear producto'})


def listar_productos(tenant_id):
    """
    GET /productos
    Listar todos los productos.
    """
    try:
        response_obj = table.scan(Limit=100)
        productos = response_obj.get('Items', [])
        productos = to_json_safe(productos)
        productos = [p for p in productos if item_belongs_to_tenant(p, tenant_id)]
        
        return response(200, {
            'total': len(productos),
            'productos': productos
        })
    
    except Exception:
        logger.exception('Error al listar productos')
        return response(500, {'error': 'Error al listar productos'})


def obtener_producto(producto_id, tenant_id):
    """
    GET /productos/{id}
    Obtener un producto específico por ID.
    """
    try:
        resultado = table.get_item(Key={'id': producto_id})
        
        if 'Item' not in resultado:
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Producto {producto_id} no encontrado'})
        
        producto = to_json_safe(resultado['Item'])
        
        return response(200, {
            'producto': producto
        })
    
    except Exception:
        logger.exception('Error al obtener producto')
        return response(500, {'error': 'Error al obtener producto'})


def actualizar_producto(producto_id, data, tenant_id):
    """
    PUT /productos/{id}
    Actualizar un producto existente.
    
    Campos que se pueden actualizar:
    - nombre
    - descripcion
    - precio
    - stock
    - categoria
    """
    try:
        # Verificar que el producto existe
        resultado = table.get_item(Key={'id': producto_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Producto {producto_id} no encontrado'})
        
        # Construir expresión de actualización
        campos_actualizables = ['nombre', 'descripcion', 'precio', 'stock', 'categoria']
        expresion_actualizar = 'SET fechaActualizacion = :ahora'
        valores = {':ahora': datetime.utcnow().isoformat()}
        
        for campo in campos_actualizables:
            if campo in data:
                if campo == 'precio':
                    valores[f':{campo}'] = Decimal(str(data[campo]))
                elif campo == 'stock':
                    valores[f':{campo}'] = int(data[campo])
                else:
                    valores[f':{campo}'] = data[campo]
                expresion_actualizar += f', {campo} = :{campo}'
        
        # Actualizar en DynamoDB
        tabla_actualizada = table.update_item(
            Key={'id': producto_id},
            UpdateExpression=expresion_actualizar,
            ExpressionAttributeValues=valores,
            ReturnValues='ALL_NEW'
        )
        
        producto = to_json_safe(tabla_actualizada['Attributes'])
        
        return response(200, {
            'mensaje': 'Producto actualizado exitosamente',
            'producto': producto
        })
    
    except Exception:
        logger.exception('Error al actualizar producto')
        return response(500, {'error': 'Error al actualizar producto'})


def eliminar_producto(producto_id, tenant_id):
    """
    DELETE /productos/{id}
    Eliminar un producto.
    """
    try:
        # Verificar que el producto existe
        resultado = table.get_item(Key={'id': producto_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Producto {producto_id} no encontrado'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Producto {producto_id} no encontrado'})
        
        # Eliminar de DynamoDB
        table.delete_item(Key={'id': producto_id})
        
        return response(200, {
            'mensaje': f'Producto {producto_id} eliminado exitosamente'
        })
    
    except Exception:
        logger.exception('Error al eliminar producto')
        return response(500, {'error': 'Error al eliminar producto'})


def response(status_code, body):
    """
    Construir respuesta HTTP estándar para API Gateway.
    """
    return build_response(status_code, body)
