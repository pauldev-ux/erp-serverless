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
ventas_table_name = resolve_table_name(os.getenv('VENTAS_TABLE'), 'ventas')
productos_table_name = resolve_table_name(os.getenv('PRODUCTOS_TABLE'), 'productos')
clientes_table_name = resolve_table_name(os.getenv('CLIENTES_TABLE'), 'clientes')
inventario_table_name = resolve_table_name(os.getenv('INVENTARIO_TABLE'), 'inventario')
ventas_table = dynamodb.Table(ventas_table_name)
productos_table = dynamodb.Table(productos_table_name)
clientes_table = dynamodb.Table(clientes_table_name)
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

        if http_method == 'POST' and path == '/ventas':
            denied = check_role_access(event, ['admin', 'vendedor'])
            if denied:
                return error_response(403, denied)
            return crear_venta(body_data, tenant_id)
        elif http_method == 'GET' and path == '/ventas':
            return listar_ventas(tenant_id)
        elif http_method == 'GET' and path == '/ventas/reportes':
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            return reporte_ventas(tenant_id)
        elif http_method == 'POST' and path.endswith('/cancelar'):
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            venta_id = path.split('/')[-2]
            return cancelar_venta(venta_id, body_data, tenant_id)
        elif http_method == 'GET' and '/ventas/' in path:
            venta_id = path.split('/')[-1]
            return obtener_venta(venta_id, tenant_id)
        else:
            return error_response(404, 'Ruta no encontrada')

    except Exception:
        logger.exception('Error general ventas')
        return error_response(500, 'Error interno del servidor')


def generar_numero_factura():
    marca = datetime.utcnow().strftime('%Y%m%d%H%M%S')
    sufijo = str(uuid.uuid4())[:8].upper()
    return f'FAC-{marca}-{sufijo}'


def crear_venta(data, tenant_id):
    """
    POST /ventas

    Body esperado:
    {
      "clienteId": "uuid",
      "productos": [
        {"productoId": "uuid", "cantidad": 2}
      ]
    }
    """
    try:
        cliente_id = data.get('clienteId')
        productos = data.get('productos', [])

        if not cliente_id:
            return response(400, {'error': 'Campo requerido: clienteId'})
        if not isinstance(productos, list) or len(productos) == 0:
            return response(400, {'error': 'Debe enviar al menos un producto'})

        cliente_result = clientes_table.get_item(Key={'id': cliente_id})
        if 'Item' not in cliente_result:
            return response(404, {'error': f'Cliente {cliente_id} no encontrado'})

        if not item_belongs_to_tenant(cliente_result['Item'], tenant_id):
            return response(404, {'error': f'Cliente {cliente_id} no encontrado'})

        detalle = []
        subtotal = Decimal('0')
        ahora = datetime.utcnow().isoformat()

        for item in productos:
            producto_id = item.get('productoId')
            cantidad = item.get('cantidad')

            if not producto_id or cantidad is None:
                return response(400, {'error': 'Cada producto requiere: productoId y cantidad'})

            try:
                cantidad = int(cantidad)
            except Exception:
                return response(400, {'error': 'Cantidad invalida'})

            if cantidad <= 0:
                return response(400, {'error': 'Cantidad debe ser mayor a 0'})

            producto_result = productos_table.get_item(Key={'id': producto_id})
            if 'Item' not in producto_result:
                return response(404, {'error': f'Producto {producto_id} no encontrado'})

            if not item_belongs_to_tenant(producto_result['Item'], tenant_id):
                return response(404, {'error': f'Producto {producto_id} no encontrado'})

            producto = to_json_safe(producto_result['Item'])
            stock_actual = int(producto.get('stock', 0))
            precio = Decimal(str(producto.get('precio', 0)))

            if cantidad > stock_actual:
                return response(400, {
                    'error': 'Stock insuficiente para venta',
                    'productoId': producto_id,
                    'stockDisponible': stock_actual
                })

            stock_nuevo = stock_actual - cantidad

            productos_table.update_item(
                Key={'id': producto_id},
                UpdateExpression='SET stock = :stock, fechaActualizacion = :fecha',
                ExpressionAttributeValues={':stock': stock_nuevo, ':fecha': ahora}
            )

            movimiento = {
                'id': str(uuid.uuid4()),
                'tenantId': tenant_id,
                'productoId': producto_id,
                'tipo': 'salida',
                'cantidad': cantidad,
                'motivo': 'Venta',
                'stockAnterior': stock_actual,
                'stockNuevo': stock_nuevo,
                'fecha': ahora,
                'usuario': data.get('usuario', 'sistema')
            }
            inventario_table.put_item(Item=movimiento)

            item_subtotal = precio * cantidad
            subtotal += item_subtotal

            detalle.append({
                'productoId': producto_id,
                'cantidad': cantidad,
                'precioUnitario': precio,
                'subtotal': item_subtotal
            })

        iva = (subtotal * Decimal('0.16')).quantize(Decimal('0.01'))
        total = (subtotal + iva).quantize(Decimal('0.01'))

        venta = {
            'id': str(uuid.uuid4()),
            'tenantId': tenant_id,
            'numeroFactura': generar_numero_factura(),
            'clienteId': cliente_id,
            'fecha': ahora,
            'estado': 'completada',
            'subtotal': subtotal,
            'iva': iva,
            'total': total,
            'productos': detalle
        }

        ventas_table.put_item(Item=venta)

        return response(201, {
            'mensaje': 'Venta creada exitosamente',
            'venta': to_json_safe(venta)
        })

    except Exception:
        logger.exception('Error al crear venta')
        return response(500, {'error': 'Error al crear venta'})


def listar_ventas(tenant_id):
    try:
        resultado = ventas_table.scan(Limit=200)
        ventas = to_json_safe(resultado.get('Items', []))
        ventas = [v for v in ventas if item_belongs_to_tenant(v, tenant_id)]
        ventas = sorted(ventas, key=lambda x: x.get('fecha', ''), reverse=True)

        return response(200, {
            'total': len(ventas),
            'ventas': ventas
        })

    except Exception:
        logger.exception('Error al listar ventas')
        return response(500, {'error': 'Error al listar ventas'})


def obtener_venta(venta_id, tenant_id):
    try:
        resultado = ventas_table.get_item(Key={'id': venta_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Venta {venta_id} no encontrada'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Venta {venta_id} no encontrada'})

        return response(200, {'venta': to_json_safe(resultado['Item'])})

    except Exception:
        logger.exception('Error al obtener venta')
        return response(500, {'error': 'Error al obtener venta'})


def cancelar_venta(venta_id, data, tenant_id):
    """
    POST /ventas/{id}/cancelar
    Revierte stock de la venta.
    """
    try:
        resultado = ventas_table.get_item(Key={'id': venta_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Venta {venta_id} no encontrada'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Venta {venta_id} no encontrada'})

        venta = to_json_safe(resultado['Item'])

        if venta.get('estado') == 'cancelada':
            return response(400, {'error': 'La venta ya está cancelada'})

        ahora = datetime.utcnow().isoformat()
        usuario = data.get('usuario', 'sistema')

        for item in venta.get('productos', []):
            producto_id = item.get('productoId')
            cantidad = int(item.get('cantidad', 0))

            producto_result = productos_table.get_item(Key={'id': producto_id})
            if 'Item' not in producto_result:
                return response(404, {'error': f'Producto {producto_id} no encontrado para reversa'})

            if not item_belongs_to_tenant(producto_result['Item'], tenant_id):
                return response(404, {'error': f'Producto {producto_id} no encontrado para reversa'})

            producto = to_json_safe(producto_result['Item'])
            stock_anterior = int(producto.get('stock', 0))
            stock_nuevo = stock_anterior + cantidad

            productos_table.update_item(
                Key={'id': producto_id},
                UpdateExpression='SET stock = :stock, fechaActualizacion = :fecha',
                ExpressionAttributeValues={':stock': stock_nuevo, ':fecha': ahora}
            )

            movimiento = {
                'id': str(uuid.uuid4()),
                'tenantId': tenant_id,
                'productoId': producto_id,
                'tipo': 'entrada',
                'cantidad': cantidad,
                'motivo': f'Cancelacion venta {venta_id}',
                'stockAnterior': stock_anterior,
                'stockNuevo': stock_nuevo,
                'fecha': ahora,
                'usuario': usuario
            }
            inventario_table.put_item(Item=movimiento)

        venta_actualizada = ventas_table.update_item(
            Key={'id': venta_id},
            UpdateExpression='SET #estado = :estado, fechaCancelacion = :fecha, usuarioCancelacion = :usuario',
            ExpressionAttributeNames={'#estado': 'estado'},
            ExpressionAttributeValues={
                ':estado': 'cancelada',
                ':fecha': ahora,
                ':usuario': usuario
            },
            ReturnValues='ALL_NEW'
        )

        return response(200, {
            'mensaje': 'Venta cancelada y stock restaurado exitosamente',
            'venta': to_json_safe(venta_actualizada['Attributes'])
        })

    except Exception:
        logger.exception('Error al cancelar venta')
        return response(500, {'error': 'Error al cancelar venta'})


def reporte_ventas(tenant_id):
    """
    GET /ventas/reportes
    Resumen simple de ventas.
    """
    try:
        resultado = ventas_table.scan(Limit=500)
        ventas = to_json_safe(resultado.get('Items', []))
        ventas = [v for v in ventas if item_belongs_to_tenant(v, tenant_id)]

        total_ventas = len(ventas)
        completadas = [v for v in ventas if v.get('estado') == 'completada']
        canceladas = [v for v in ventas if v.get('estado') == 'cancelada']

        monto_total = sum(float(v.get('total', 0)) for v in completadas)

        return response(200, {
            'totalVentas': total_ventas,
            'ventasCompletadas': len(completadas),
            'ventasCanceladas': len(canceladas),
            'montoTotalCompletadas': round(monto_total, 2)
        })

    except Exception:
        logger.exception('Error al generar reporte de ventas')
        return response(500, {'error': 'Error al generar reporte'})


def response(status_code, body):
    return build_response(status_code, body)
