# Guia de estudio - Flujo integral ERP Serverless

## Objetivo de esta guia

Documentar el flujo completo validado en local:
- Crear cliente
- Crear producto
- Verificar stock inicial
- Crear venta
- Verificar stock despues de venta
- Cancelar venta
- Verificar stock restaurado

Resultado esperado del flujo:
- Stock Inicial: 10
- Stock Despues Venta: 8
- Stock Final: 10

---

## 1) Configuracion de consola (PowerShell UTF-8)

Usar estos comandos para evitar errores de codificacion en requests JSON:

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
```

Headers usados:

```powershell
$headers = @{
  "x-api-role" = "admin"
  "Content-Type" = "application/json; charset=utf-8"
}
```

---

## 2) Flujo de pruebas (comandos)

### 2.1 Crear cliente

```powershell
$clienteBody = @{
  nombre    = "Juan Perez"
  email     = "juan@test.com"
  telefono  = "555-1234"
  direccion = "Calle 1"
  rfc       = "JUA123456XYZ"
} | ConvertTo-Json -Compress

$clienteResp = Invoke-RestMethod -Uri "http://127.0.0.1:3000/clientes" -Method Post -Headers $headers -Body $clienteBody
$clienteId = $clienteResp.cliente.id
Write-Output "Cliente: $clienteId"
```

Salida observada:

```text
Cliente: b27f427a-5bb7-4b62-84a2-301e253e8455
```

### 2.2 Crear producto

```powershell
$productoBody = @{
  nombre      = "Laptop"
  descripcion = "Laptop HP"
  precio      = 800
  stock       = 10
  categoria   = "Electronica"
} | ConvertTo-Json -Compress

$productoResp = Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Post -Headers $headers -Body $productoBody
$productoId = $productoResp.producto.id
Write-Output "Producto: $productoId"
```

Salida observada:

```text
Producto: a698df54-295e-4c38-aba5-4b0511db9da1
```

### 2.3 Consultar inventario (stock inicial)

```powershell
$inv1 = Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/$productoId" -Method Get
$inv1 | ConvertTo-Json -Depth 5
Write-Output "Stock Inicial: $($inv1.stock)"
```

Salida observada:

```text
{
  "productoId": "a698df54-295e-4c38-aba5-4b0511db9da1",
  "nombre": "Laptop",
  "stock": 10,
  "categoria": "Electronica",
  "fechaActualizacion": "2026-03-23T05:08:08.587799"
}
Stock Inicial: 10
```

### 2.4 Crear venta

```powershell
$ventaBody = @{
  clienteId = $clienteId
  productos = @(
    @{
      productoId     = $productoId
      cantidad       = 2
      precioUnitario = 800
    }
  )
} | ConvertTo-Json -Compress -Depth 4

$ventaResp = Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas" -Method Post -Headers $headers -Body $ventaBody
$ventaId = $ventaResp.venta.id
Write-Output "Venta: $($ventaResp.venta.numeroFactura)"
```

Salida observada:

```text
Venta: FAC-20260323050959-BFDC02F6
```

### 2.5 Verificar stock despues de venta

```powershell
$inv2 = Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/$productoId" -Method Get
$inv2 | ConvertTo-Json -Depth 5
Write-Output "Stock Despues Venta: $($inv2.stock)"
```

Salida observada:

```text
{
  "productoId": "a698df54-295e-4c38-aba5-4b0511db9da1",
  "nombre": "Laptop",
  "stock": 8,
  "categoria": "Electronica",
  "fechaActualizacion": "2026-03-23T05:09:58.920996"
}
Stock Despues Venta: 8
```

### 2.6 Cancelar venta

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/ventas/$ventaId/cancelar" -Method Post -Headers $headers | Out-Null
Write-Output "Venta cancelada"
```

Salida observada:

```text
Venta cancelada
```

### 2.7 Verificar stock final (restaurado)

```powershell
$inv3 = Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/$productoId" -Method Get
$inv3 | ConvertTo-Json -Depth 5
Write-Output "Stock Final: $($inv3.stock)"
```

Salida observada:

```text
{
  "productoId": "a698df54-295e-4c38-aba5-4b0511db9da1",
  "nombre": "Laptop",
  "stock": 10,
  "categoria": "Electronica",
  "fechaActualizacion": "2026-03-23T05:10:34.305648"
}
Stock Final: 10
```

---

## 3) Error que aparecio y como se resolvio

Error visto:

```text
Stock Inicial:
Stock Despues Venta:
Stock Final:
```

Causa:
- Se intentaba leer `inventario.stock`.
- La respuesta real de `/inventario/{productoId}` trae `stock` en la raiz.

Forma correcta:

```powershell
$inv1.stock
$inv2.stock
$inv3.stock
```

---

## 4) Conclusiones para estudio

- El flujo integral de negocio quedo validado en local.
- La venta descuenta stock correctamente.
- La cancelacion restaura stock correctamente.
- La lectura correcta de la respuesta de inventario es por propiedad raiz (`stock`).
- Para PowerShell, conviene fijar UTF-8 antes de enviar bodies JSON.
