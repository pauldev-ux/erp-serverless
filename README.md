# ERP Serverless

API serverless para gestion de Productos, Clientes, Inventario, Ventas y Compras (extra), construida con AWS SAM, Lambda, API Gateway y DynamoDB.

## Estado del proyecto

- Modulos obligatorios completos: Productos, Clientes, Inventario y Ventas.
- Modulo extra implementado: Compras.
- Flujo integral validado: stock 10 -> 8 -> 10 al vender y cancelar venta.
- Fase 7 (Seguridad): completada (Cognito + roles + errores centralizados + OpenAPI basico).

## Arquitectura

- API Gateway (REST)
- 5 Lambdas Python 3.11 (una por modulo)
- DynamoDB con tablas por modulo
- Autorizacion por rol configurable:
  - `header` (x-api-role)
  - `cognito` (token Bearer + atributo de rol)
  - `hybrid` (Cognito y fallback header)

Diagrama listo para exportar: ver [docs/arquitectura.md](docs/arquitectura.md).

## Estructura principal

```text
erp-serverless/
├── template.yaml
├── src/handlers/
│   ├── auth.py
│   ├── http_utils.py
│   ├── productos.py
│   ├── clientes.py
│   ├── inventario.py
│   ├── ventas.py
│   └── compras.py
├── tests/
│   ├── unit/
│   └── integration/
├── postman/
│   ├── ERP_Serverless_Base.postman_collection.json
│   └── ERP_Serverless_Local.postman_environment.json
└── docs/
    ├── arquitectura.md
    └── despliegue-paso-a-paso.md
```

## Requisitos

- Python 3.11+
- Docker
- AWS SAM CLI
- AWS CLI

## Instalacion

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

## Ejecutar local

1. Levantar DynamoDB local:

```bash
docker run -p 8000:8000 amazon/dynamodb-local
```

2. Construir proyecto:

```bash
sam build --no-cached
```

3. Levantar API local:

```bash
sam local start-api
```

& "C:\Program Files\Amazon\AWSSAMCLI\bin\sam.cmd" build

& "C:\Program Files\Amazon\AWSSAMCLI\bin\sam.cmd" local start-api

API local: `http://127.0.0.1:3000`

## Variables de entorno de seguridad

Definidas en `template.yaml` (Globals -> Function -> Environment):

- `AUTH_ENABLED`: `true|false`
- `AUTH_PROVIDER`: `header|cognito|hybrid`
- `AUTH_HEADER`: por defecto `x-api-role`
- `COGNITO_ROLE_ATTRIBUTE`: por defecto `custom:role`

### Modos de autenticacion

1. `header`:
- Usa `x-api-role` en headers.

2. `cognito`:
- Usa `Authorization: Bearer <access_token>`.
- Resuelve rol desde atributo de usuario Cognito (`custom:role` por defecto).

3. `hybrid`:
- Intenta Cognito y, si no resuelve rol, usa header.

## Endpoints

### Productos

- `POST /productos` (admin)
- `GET /productos`
- `GET /productos/{id}`
- `PUT /productos/{id}` (admin)
- `DELETE /productos/{id}` (admin)

### Clientes

- `POST /clientes` (admin)
- `GET /clientes`
- `GET /clientes/{id}`
- `PUT /clientes/{id}` (admin)
- `DELETE /clientes/{id}` (admin)

### Inventario

- `GET /inventario`
- `GET /inventario/{productoId}`
- `POST /inventario/movimiento` (admin)
- `GET /inventario/movimientos`
- `GET /inventario/alertas?minStock=5`

### Ventas

- `POST /ventas` (admin|vendedor)
- `GET /ventas`
- `GET /ventas/{id}`
- `POST /ventas/{id}/cancelar` (admin)
- `GET /ventas/reportes` (admin)

### Compras (extra)

- `POST /compras` (admin)
- `GET /compras`
- `GET /compras/{id}`
- `PUT /compras/{id}/estado` (admin)
- `POST /compras/{id}/recibir` (admin)

## Ejemplos de requests

### Crear cliente

```bash
curl -X POST "http://127.0.0.1:3000/clientes" \
  -H "Content-Type: application/json" \
  -H "x-api-role: admin" \
  -d '{"nombre":"Juan Perez","email":"juan@test.com","telefono":"555-1234","direccion":"Calle 1","rfc":"JUA123456XYZ"}'
```

### Crear producto

```bash
curl -X POST "http://127.0.0.1:3000/productos" \
  -H "Content-Type: application/json" \
  -H "x-api-role: admin" \
  -d '{"nombre":"Laptop","descripcion":"Laptop HP","precio":800,"stock":10,"categoria":"Electronica"}'
```

### Crear venta

```bash
curl -X POST "http://127.0.0.1:3000/ventas" \
  -H "Content-Type: application/json" \
  -H "x-api-role: admin" \
  -d '{"clienteId":"<clienteId>","productos":[{"productoId":"<productoId>","cantidad":2,"precioUnitario":800}]}'
```

### Cancelar venta

```bash
curl -X POST "http://127.0.0.1:3000/ventas/<ventaId>/cancelar" \
  -H "Content-Type: application/json" \
  -H "x-api-role: admin" \
  -d '{"usuario":"admin"}'
```

## Pruebas

Ejecutar pruebas:

```bash
python -m pytest -q
```

Estado actual: 9 pruebas pasando.

## Postman

Importar:

- Coleccion: [postman/ERP_Serverless_Base.postman_collection.json](postman/ERP_Serverless_Base.postman_collection.json)
- Environment: [postman/ERP_Serverless_Local.postman_environment.json](postman/ERP_Serverless_Local.postman_environment.json)

## OpenAPI

Documento OpenAPI basico en: [OPENAPI_BASICO_OBLIGATORIOS.yaml](OPENAPI_BASICO_OBLIGATORIOS.yaml)

## Despliegue

Guia corta paso a paso en: [docs/despliegue-paso-a-paso.md](docs/despliegue-paso-a-paso.md)
