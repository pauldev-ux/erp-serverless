# Resumen de Implementacion - Modulo Compras

Fecha: 22 de marzo de 2026  
Proyecto: ERP Serverless (AWS SAM + Python)

---

## Objetivo
Implementar el modulo de Compras con integracion a Productos e Inventario.

---

## Implementacion realizada

### 1) Handler del modulo
Archivo creado:
- `src/handlers/compras.py`

Funciones implementadas:
- `POST /compras` -> crear orden de compra
- `GET /compras` -> listar ordenes
- `GET /compras/{id}` -> obtener orden por id
- `PUT /compras/{id}/estado` -> actualizar estado (pendiente/recibida/cancelada)
- `POST /compras/{id}/recibir` -> recibir mercancia y actualizar stock

### 2) Integraciones de negocio
- Valida que los productos existan al crear compra.
- Calcula total y subtotales de la orden.
- Al recibir mercancia:
  - Actualiza stock en tabla `productos`.
  - Registra movimiento de entrada en tabla `inventario`.
  - Marca compra como `recibida`.

### 3) Infraestructura SAM
Archivo actualizado:
- `template.yaml`

Recursos agregados:
- `ComprasFunction`
- `ComprasTable` (DynamoDB)
- `ComprasLogGroup`
- Output `ComprasTableName`

Rutas agregadas:
- `GET /compras`
- `POST /compras`
- `GET /compras/{id}`
- `PUT /compras/{id}/estado`
- `POST /compras/{id}/recibir`

---

## Evidencia de pruebas ejecutadas

### 1) Build y API local
```powershell
cd D:\Universidad\Topicos\serverless\erp-serverless
sam build --no-cached
sam local start-api --profile erp-dev --region us-east-2
```

### 2) Crear tabla compras (si no existe)
```powershell
aws dynamodb create-table \
  --table-name compras \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2 \
  --profile erp-dev

aws dynamodb wait table-exists --table-name compras --region us-east-2 --profile erp-dev
```

Resultado:
- Tabla `compras` creada y disponible.

### 3) Crear compra
```powershell
$bodyCompra = @{
  proveedor = "Proveedor A"
  observaciones = "Entrega parcial"
  productos = @(
    @{ productoId = "4e80fbc3-ab33-482b-b71f-23c2b354fd96"; cantidad = 12; precioUnitario = 100 },
    @{ productoId = "4e80fbc3-ab33-482b-b71f-23c2b354fd96"; cantidad = 3; precioUnitario = 95 }
  )
} | ConvertTo-Json -Depth 5

$compra = Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras" -Method Post -ContentType "application/json" -Body $bodyCompra
$compra
```

Resultado:
- Orden creada exitosamente.
- Estado inicial: `pendiente`.
- Total calculado correctamente.

### 4) Listar compras
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras" -Method Get
```

Resultado:
- Lista de compras devuelta correctamente.

### 5) Obtener compra por ID
```powershell
$compraId = $compra.compra.id
Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras/$compraId" -Method Get
```

Resultado:
- Compra obtenida correctamente por ID.

### 6) Actualizar estado
```powershell
$estado = @{ estado = "pendiente" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras/$compraId/estado" -Method Put -ContentType "application/json" -Body $estado
```

Resultado:
- Estado actualizado correctamente.

### 7) Recibir mercancia (actualiza stock)
```powershell
$recepcion = @{ usuario = "ferna"; motivo = "Recepcion bodega" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras/$compraId/recibir" -Method Post -ContentType "application/json" -Body $recepcion
```

Resultado:
- Mercancia recibida correctamente.
- Stock de productos actualizado.
- Movimientos de inventario registrados.
- Compra marcada como `recibida`.

### 8) Validar que no se pueda recibir dos veces
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/compras/$compraId/recibir" -Method Post -ContentType "application/json" -Body $recepcion
```

Resultado esperado:
- Segunda recepcion debe devolver error controlado.

Resultado obtenido:
- Error controlado correcto: `La compra ya fue recibida anteriormente`.

---

## Estado
- Fase 5 validada end-to-end en entorno local.
- Estado final: Fase 5 completada (validación local).
