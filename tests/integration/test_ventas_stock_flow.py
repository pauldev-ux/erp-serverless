import importlib
import json
from decimal import Decimal


class FakeTable:
    def __init__(self, items=None):
        self.items = items or {}

    def get_item(self, Key):
        item_id = Key.get('id')
        if item_id in self.items:
            return {'Item': self.items[item_id]}
        return {}

    def put_item(self, Item):
        item_id = Item.get('id')
        if item_id:
            self.items[item_id] = Item
        return {'ResponseMetadata': {'HTTPStatusCode': 200}}

    def update_item(
        self,
        Key,
        UpdateExpression=None,
        ExpressionAttributeValues=None,
        ExpressionAttributeNames=None,
        ReturnValues=None,
    ):
        item_id = Key['id']
        current = self.items[item_id]

        # Apply only fields used by ventas.py
        if ':stock' in (ExpressionAttributeValues or {}):
            current['stock'] = ExpressionAttributeValues[':stock']

        if ':fecha' in (ExpressionAttributeValues or {}):
            current['fechaActualizacion'] = ExpressionAttributeValues[':fecha']

        if ':estado' in (ExpressionAttributeValues or {}):
            current['estado'] = ExpressionAttributeValues[':estado']

        if ':usuario' in (ExpressionAttributeValues or {}):
            current['usuarioCancelacion'] = ExpressionAttributeValues[':usuario']

        if ':fecha' in (ExpressionAttributeValues or {}) and ':estado' in (ExpressionAttributeValues or {}):
            current['fechaCancelacion'] = ExpressionAttributeValues[':fecha']

        self.items[item_id] = current
        return {'Attributes': current}

    def scan(self, Limit=None):
        return {'Items': list(self.items.values())}


class FakeDynamoResource:
    def __init__(self):
        self.tables = {
            'ventas': FakeTable({}),
            'productos': FakeTable({}),
            'clientes': FakeTable({}),
            'inventario': FakeTable({}),
        }

    def Table(self, name):
        return self.tables[name]


def test_stock_flow_create_sale_and_cancel(monkeypatch):
    # Ensure module imports in local/test mode and uses fake dynamo resource.
    monkeypatch.setenv('AWS_SAM_LOCAL', 'true')
    monkeypatch.setenv('AWS_ENDPOINT_URL_DYNAMODB', 'http://localhost:8000')

    fake_resource = FakeDynamoResource()

    import boto3

    monkeypatch.setattr(boto3, 'resource', lambda *args, **kwargs: fake_resource)

    ventas = importlib.import_module('ventas')
    ventas = importlib.reload(ventas)

    # Seed fake tables
    ventas.productos_table.items['p1'] = {
        'id': 'p1',
        'tenantId': 'tenant-test',
        'nombre': 'Laptop',
        'precio': Decimal('800'),
        'stock': 10,
        'categoria': 'Electronica',
        'fechaActualizacion': '2026-03-23T05:00:00'
    }
    ventas.clientes_table.items['c1'] = {
        'id': 'c1',
        'tenantId': 'tenant-test',
        'nombre': 'Juan Perez',
        'email': 'juan@test.com',
        'telefono': '555-1234'
    }

    crear_resp = ventas.crear_venta(
        {
            'clienteId': 'c1',
            'productos': [
                {
                    'productoId': 'p1',
                    'cantidad': 2,
                    'precioUnitario': 800,
                }
            ],
        },
        'tenant-test'
    )

    assert crear_resp['statusCode'] == 201
    crear_body = json.loads(crear_resp['body'])
    venta_id = crear_body['venta']['id']

    # Stock decreased after sale
    assert ventas.productos_table.items['p1']['stock'] == 8

    cancelar_resp = ventas.cancelar_venta(venta_id, {'usuario': 'test'}, 'tenant-test')

    assert cancelar_resp['statusCode'] == 200

    # Stock restored after cancellation
    assert ventas.productos_table.items['p1']['stock'] == 10
