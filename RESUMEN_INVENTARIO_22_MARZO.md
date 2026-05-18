# Resumen de Pruebas - Modulo Inventario

Fecha: 22 de marzo de 2026  
Proyecto: ERP Serverless (AWS SAM + Python)

---

## Objetivo
Validar operaciones clave del modulo Inventario en entorno local (SAM + Docker) con DynamoDB real en AWS.

---

## Evidencia de ejecucion

### 1) Diagnostico inicial
Comando:
```powershell
aws dynamodb describe-table --table-name inventario --region us-east-2 --profile erp-dev
```
Resultado:
- Error: `ResourceNotFoundException`.
- Causa confirmada: tabla `inventario` no existia.

### 2) Creacion de tabla inventario
Comando:
```powershell
aws dynamodb create-table \
  --table-name inventario \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2 \
  --profile erp-dev
```
Resultado:
- Tabla creada correctamente.
- ARN confirmado: `arn:aws:dynamodb:us-east-2:425182213169:table/inventario`.

### 3) Espera de disponibilidad
Comando:
```powershell
aws dynamodb wait table-exists --table-name inventario --region us-east-2 --profile erp-dev
```
Resultado:
- Tabla lista para uso.

### 4) Registro de movimiento (entrada)
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimiento" -Method Post -ContentType "application/json" -Body $entrada
```
Resultado:
- Mensaje: `Movimiento de inventario registrado exitosamente`.
- Movimiento guardado con `tipo=entrada`.

---

## Estado actual del modulo
- Tabla inventario: creada y operativa.
- Endpoint `POST /inventario/movimiento`: validado (entrada y salida).
- Integracion con productos (actualizacion de stock): activa.

---

## Validaciones completadas adicionales

### 5) Consulta por producto
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/$productoId" -Method Get
```
Resultado:
- Stock inicial consultado correctamente (10) y luego actualizado.

### 6) Registro de salida
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimiento" -Method Post -ContentType "application/json" -Body $salida
```
Resultado:
- Movimiento de salida registrado exitosamente.
- Stock del producto disminuye de 50 a 45.

### 7) Historial de movimientos
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimientos" -Method Get
```
Resultado:
- Historial devuelto correctamente con 2 movimientos (entrada y salida).

### 8) Alertas de stock bajo
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/alertas?minStock=30" -Method Get
```
Resultado:
- Respuesta correcta con `totalAlertas = 0` (sin productos bajo umbral).

### 9) Error controlado por stock insuficiente
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimiento" -Method Post -ContentType "application/json" -Body $salidaInvalida
```
Resultado:
- Error esperado y controlado:
  - `Stock insuficiente para realizar la salida`
  - `stockDisponible = 45`

---

## Pruebas pendientes para cerrar modulo al 100%
No hay pendientes funcionales del modulo Inventario en entorno local.

---

## Comandos listos para continuar
```powershell
# 1) Salida de stock
$salida = @{
  productoId = "4e80fbc3-ab33-482b-b71f-23c2b354fd96"
  tipo = "salida"
  cantidad = 5
  motivo = "Venta mostrador"
  usuario = "ferna"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimiento" -Method Post -ContentType "application/json" -Body $salida

# 2) Historial
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimientos" -Method Get

# 3) Alertas
Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/alertas?minStock=10" -Method Get

# 4) Prueba de stock insuficiente
$pruebaError = @{
  productoId = "4e80fbc3-ab33-482b-b71f-23c2b354fd96"
  tipo = "salida"
  cantidad = 99999
  motivo = "Prueba error"
  usuario = "ferna"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://127.0.0.1:3000/inventario/movimiento" -Method Post -ContentType "application/json" -Body $pruebaError
```

---

## Conclusiones
El modulo Inventario quedo validado end-to-end en entorno local:
- Consulta de inventario.
- Movimientos de entrada y salida.
- Historial de movimientos.
- Alertas por umbral de stock.
- Manejo correcto de error por stock insuficiente.

Estado final: Fase 4 completada en validacion local.
