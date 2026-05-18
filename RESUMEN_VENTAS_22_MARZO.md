# Resumen de Implementacion - Modulo Ventas

Fecha: 22 de marzo de 2026  
Proyecto: ERP Serverless (AWS SAM + Python)

---

## Objetivo
Implementar el modulo de Ventas con integracion a Clientes, Productos e Inventario.

---

## Implementacion realizada

### 1) Handler del modulo
Archivo creado:
- `src/handlers/ventas.py`

Funciones implementadas:
- `POST /ventas` -> crear venta
- `GET /ventas` -> listar ventas
- `GET /ventas/{id}` -> obtener venta por id
- `POST /ventas/{id}/cancelar` -> cancelar venta y restaurar stock
- `GET /ventas/reportes` -> resumen de ventas

### 2) Integraciones de negocio
- Valida que el cliente exista antes de vender.
- Valida que cada producto exista y tenga stock suficiente.
- Descuenta stock en `productos` al confirmar venta.
- Registra movimiento de inventario tipo `salida` por cada item vendido.
- Al cancelar venta:
  - Restaura stock en `productos`.
  - Registra movimiento tipo `entrada` en `inventario`.
- Genera numero de factura automatico (`FAC-YYYYMMDDHHMMSS-XXXXXXXX`).
- Calcula `subtotal`, `iva` y `total`.

### 3) Infraestructura SAM
Archivo actualizado:
- `template.yaml`

Recursos agregados:
- `VentasFunction`
- `VentasTable` (DynamoDB)
- `VentasLogGroup`
- Output `VentasTableName`

Rutas agregadas:
- `GET /ventas`
- `POST /ventas`
- `GET /ventas/{id}`
- `POST /ventas/{id}/cancelar`
- `GET /ventas/reportes`

---

## Evidencia de validacion ejecutada

### 1) Build y API local
```powershell
cd D:\Universidad\Topicos\serverless\erp-serverless
sam validate
sam build --no-cached
sam local start-api --profile erp-dev --region us-east-2
```

Resultado:
- `sam validate`: template valido.
- `sam build --no-cached`: compilacion exitosa.

### 2) Crear tabla ventas (si no existe)
```powershell
aws dynamodb create-table --table-name ventas --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-2 --profile erp-dev

aws dynamodb wait table-exists --table-name ventas --region us-east-2 --profile erp-dev
aws dynamodb describe-table --table-name ventas --region us-east-2 --profile erp-dev
```

Resultado:
- Tabla `ventas` creada y en estado `ACTIVE`.

### 3) Crear venta
```powershell
$bodyVenta = @{
  clienteId = "ID_CLIENTE_EXISTENTE"
  usuario = "ferna"
  productos = @(
    @{ productoId = "ID_PRODUCTO_1"; cantidad = 2 },
    @{ productoId = "ID_PRODUCTO_2"; cantidad = 1 }
  )
} | ConvertTo-Json -Depth 5

$venta = Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas" -Method Post -ContentType "application/json" -Body $bodyVenta
$venta
```

### 4) Listar ventas
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas" -Method Get
```

### 5) Obtener venta por ID
```powershell
$ventaId = $venta.venta.id
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas/$ventaId" -Method Get
```

### 6) Cancelar venta
```powershell
$bodyCancelar = @{ usuario = "ferna" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas/$ventaId/cancelar" -Method Post -ContentType "application/json" -Body $bodyCancelar
```

### 7) Reportes
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas/reportes" -Method Get
```

Resultado observado:
- `totalVentas = 1`
- `ventasCompletadas = 1`
- `ventasCanceladas = 0`
- `montoTotalCompletadas = 1740.00`

### 8) Resultado final de la cancelacion
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas/$ventaId/cancelar" -Method Post -ContentType "application/json" -Body $bodyCancelar
```

Resultado observado:
- Mensaje: `Venta cancelada y stock restaurado exitosamente`.
- La venta queda en estado `cancelada`.
- Se confirma reversa de stock y registro de movimiento en inventario.

---

## Estado
- Fase 6 completada al 100% en validacion local.
- Flujo validado end-to-end: crear venta, obtener venta, reportes y cancelar con restauracion de stock.
