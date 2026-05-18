import os
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
compras_table_name = resolve_table_name(os.getenv('COMPRAS_TABLE'), 'compras')
productos_table_name = resolve_table_name(os.getenv('PRODUCTOS_TABLE'), 'productos')
inventario_table_name = resolve_table_name(os.getenv('INVENTARIO_TABLE'), 'inventario')
compras_table = dynamodb.Table(compras_table_name)
productos_table = dynamodb.Table(productos_table_name)
inventario_table = dynamodb.Table(inventario_table_name)


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

        try:
            body_data = parse_json_body(body)
        except ValueError as exc:
            return error_response(400, str(exc))

        tenant_id, tenant_error = resolve_tenant_id(event)
        if tenant_error:
            return error_response(400, tenant_error)

        if http_method == 'POST' and path == '/compras':
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            return crear_compra(body_data, tenant_id)
        elif http_method == 'GET' and path == '/compras':
            return listar_compras(tenant_id)
        elif http_method == 'GET' and '/compras/' in path and '/estado' not in path and '/recibir' not in path:
            compra_id = path.split('/')[-1]
            return obtener_compra(compra_id, tenant_id)
        elif http_method == 'PUT' and path.endswith('/estado'):
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            compra_id = path.split('/')[-2]
            return actualizar_estado_compra(compra_id, body_data, tenant_id)
        elif http_method == 'POST' and path.endswith('/recibir'):
            denied = check_role_access(event, ['admin'])
            if denied:
                return error_response(403, denied)
            compra_id = path.split('/')[-2]
            return recibir_mercancia(compra_id, body_data, tenant_id)
        else:
            return error_response(404, 'Ruta no encontrada')

    except Exception as e:
        print(f"Error general compras: {str(e)}")
        return error_response(500, 'Error interno del servidor')


def crear_compra(data, tenant_id):
    """
    POST /compras

    Body esperado:
    {
      "proveedor": "string",
      "productos": [
        {"productoId": "uuid", "cantidad": 10, "precioUnitario": 20.5}
      ]
    }
    """
    try:
        if not data.get('proveedor'):
            return response(400, {'error': 'Campo requerido: proveedor'})

        productos = data.get('productos', [])
        if not isinstance(productos, list) or len(productos) == 0:
            return response(400, {'error': 'Debe enviar al menos un producto en la compra'})

        total = Decimal('0')
        detalles = []

        for item in productos:
            producto_id = item.get('productoId')
            cantidad = item.get('cantidad')
            precio_unitario = item.get('precioUnitario')

            if not producto_id or cantidad is None or precio_unitario is None:
                return response(400, {'error': 'Cada producto requiere: productoId, cantidad y precioUnitario'})

            try:
                cantidad = int(cantidad)
                precio_unitario = Decimal(str(precio_unitario))
            except Exception:
                return response(400, {'error': 'Cantidad o precioUnitario invalido'})

            if cantidad <= 0 or precio_unitario <= 0:
                return response(400, {'error': 'Cantidad y precioUnitario deben ser mayores a 0'})

            producto_result = productos_table.get_item(Key={'id': producto_id})
            if 'Item' not in producto_result:
                return response(404, {'error': f'Producto {producto_id} no encontrado'})

            if not item_belongs_to_tenant(producto_result['Item'], tenant_id):
                return response(404, {'error': f'Producto {producto_id} no encontrado'})

            subtotal = precio_unitario * cantidad
            total += subtotal

            detalles.append({
                'productoId': producto_id,
                'cantidad': cantidad,
                'precioUnitario': precio_unitario,
                'subtotal': subtotal
            })

        compra = {
            'id': str(uuid.uuid4()),
            'tenantId': tenant_id,
            'proveedor': data['proveedor'],
            'fecha': datetime.utcnow().isoformat(),
            'estado': 'pendiente',
            'total': total,
            'productos': detalles,
            'observaciones': data.get('observaciones', '')
        }

        compras_table.put_item(Item=compra)

        return response(201, {
            'mensaje': 'Orden de compra creada exitosamente',
            'compra': to_json_safe(compra)
        })

    except Exception as e:
        print(f"Error al crear compra: {str(e)}")
        return response(500, {'error': 'Error al crear orden de compra'})


def listar_compras(tenant_id):
    """
    GET /compras
    Lista todas las ordenes de compra.
    """
    try:
        resultado = compras_table.scan(Limit=200)
        compras = to_json_safe(resultado.get('Items', []))
        compras = [c for c in compras if item_belongs_to_tenant(c, tenant_id)]
        compras = sorted(compras, key=lambda x: x.get('fecha', ''), reverse=True)

        return response(200, {
            'total': len(compras),
            'compras': compras
        })

    except Exception as e:
        print(f"Error al listar compras: {str(e)}")
        return response(500, {'error': 'Error al listar compras'})


def obtener_compra(compra_id, tenant_id):
    """
    GET /compras/{id}
    """
    try:
        resultado = compras_table.get_item(Key={'id': compra_id})
        if 'Item' not in resultado:
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        if not item_belongs_to_tenant(resultado['Item'], tenant_id):
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        return response(200, {'compra': to_json_safe(resultado['Item'])})

    except Exception as e:
        print(f"Error al obtener compra: {str(e)}")
        return response(500, {'error': 'Error al obtener compra'})


def actualizar_estado_compra(compra_id, data, tenant_id):
    """
    PUT /compras/{id}/estado

    Body esperado:
    {
      "estado": "pendiente|recibida|cancelada"
    }
    """
    try:
        nuevo_estado = str(data.get('estado', '')).lower()
        estados_validos = ['pendiente', 'recibida', 'cancelada']

        if nuevo_estado not in estados_validos:
            return response(400, {'error': f'Estado invalido. Valores permitidos: {", ".join(estados_validos)}'})

        compra_result = compras_table.get_item(Key={'id': compra_id})
        if 'Item' not in compra_result:
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        if not item_belongs_to_tenant(compra_result['Item'], tenant_id):
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        compra = to_json_safe(compra_result['Item'])

        if compra.get('estado') == 'recibida' and nuevo_estado != 'recibida':
            return response(400, {'error': 'No se puede cambiar una compra recibida a otro estado'})

        actualizada = compras_table.update_item(
            Key={'id': compra_id},
            UpdateExpression='SET #estado = :estado, fechaActualizacion = :fecha',
            ExpressionAttributeNames={'#estado': 'estado'},
            ExpressionAttributeValues={
                ':estado': nuevo_estado,
                ':fecha': datetime.utcnow().isoformat()
            },
            ReturnValues='ALL_NEW'
        )

        return response(200, {
            'mensaje': 'Estado de compra actualizado exitosamente',
            'compra': to_json_safe(actualizada['Attributes'])
        })

    except Exception as e:
        print(f"Error al actualizar estado de compra: {str(e)}")
        return response(500, {'error': 'Error al actualizar estado de compra'})


def recibir_mercancia(compra_id, data, tenant_id):
    """
    POST /compras/{id}/recibir

    Registra la recepcion de mercancia y actualiza inventario.
    """
    try:
        compra_result = compras_table.get_item(Key={'id': compra_id})
        if 'Item' not in compra_result:
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        if not item_belongs_to_tenant(compra_result['Item'], tenant_id):
            return response(404, {'error': f'Compra {compra_id} no encontrada'})

        compra = to_json_safe(compra_result['Item'])

        if compra.get('estado') == 'cancelada':
            return response(400, {'error': 'No se puede recibir mercancia de una compra cancelada'})
        if compra.get('estado') == 'recibida':
            return response(400, {'error': 'La compra ya fue recibida anteriormente'})

        usuario = data.get('usuario', 'sistema')
        motivo = data.get('motivo', f'Recepcion de compra {compra_id}')
        ahora = datetime.utcnow().isoformat()

        movimientos = []

        for item in compra.get('productos', []):
            producto_id = item.get('productoId')
            cantidad = int(item.get('cantidad', 0))

            producto_result = productos_table.get_item(Key={'id': producto_id})
            if 'Item' not in producto_result:
                return response(404, {'error': f'Producto {producto_id} no encontrado durante recepcion'})

            if not item_belongs_to_tenant(producto_result['Item'], tenant_id):
                return response(404, {'error': f'Producto {producto_id} no encontrado durante recepcion'})

            producto = to_json_safe(producto_result['Item'])
            stock_anterior = int(producto.get('stock', 0))
            stock_nuevo = stock_anterior + cantidad

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
                'tipo': 'entrada',
                'cantidad': cantidad,
                'motivo': motivo,
                'stockAnterior': stock_anterior,
                'stockNuevo': stock_nuevo,
                'fecha': ahora,
                'usuario': usuario
            }

            inventario_table.put_item(Item=movimiento)
            movimientos.append(movimiento)

        compra_actualizada = compras_table.update_item(
            Key={'id': compra_id},
            UpdateExpression='SET #estado = :estado, fechaRecepcion = :fecha, usuarioRecepcion = :usuario',
            ExpressionAttributeNames={'#estado': 'estado'},
            ExpressionAttributeValues={
                ':estado': 'recibida',
                ':fecha': ahora,
                ':usuario': usuario
            },
            ReturnValues='ALL_NEW'
        )

        return response(200, {
            'mensaje': 'Mercancia recibida y stock actualizado exitosamente',
            'compra': to_json_safe(compra_actualizada['Attributes']),
            'movimientos': to_json_safe(movimientos)
        })

    except Exception as e:
        print(f"Error al recibir mercancia: {str(e)}")
        return response(500, {'error': 'Error al recibir mercancia'})


def response(status_code, body):
    return build_response(status_code, body)
