# Resumen de Pruebas - Modulo Productos

Fecha: 22 de marzo de 2026  
Proyecto: ERP Serverless (AWS SAM + Python)

---

## Objetivo
Validar el CRUD completo del modulo Productos en entorno local con AWS SAM + Docker + DynamoDB.

---

## Entorno usado
- API local: `sam local start-api --profile erp-dev --region us-east-2`
- Tabla DynamoDB: `productos`
- Region: `us-east-2`
- Perfil AWS CLI: `erp-dev`

---

## Evidencia de ejecucion

### 1) Error inicial al listar productos
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```
Resultado:
- Error: `{"error": "Error al listar productos"}`

Causa identificada:
- La tabla `productos` aun no existia en DynamoDB.

---

### 2) Creacion de tabla DynamoDB
Comando ejecutado:
```powershell
aws dynamodb create-table \
  --table-name productos \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2 \
  --profile erp-dev
```
Resultado:
- Tabla creada correctamente (`TableStatus: CREATING`).
- ARN confirmado: `arn:aws:dynamodb:us-east-2:425182213169:table/productos`.

---

### 3) GET /productos
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```
Resultado:
- Respuesta correcta con `total = 0` y lista vacia.

---

### 4) POST /productos (primer producto)
Payload usado:
```json
{
  "nombre": "Laptop",
  "descripcion": "Dell i7",
  "precio": 1500,
  "stock": 10,
  "categoria": "Tecnologia"
}
```
Resultado:
- Producto creado exitosamente.
- `id` generado y retornado en respuesta.

---

### 5) GET /productos (listado con datos)
Resultado:
- Retorna `total = 1` con producto registrado.

---

### 6) POST /productos (segundo producto)
Payload usado:
```json
{
  "nombre": "Mouse",
  "descripcion": "Inalambrico",
  "precio": 25,
  "stock": 50,
  "categoria": "Accesorios"
}
```
Resultado:
- Producto creado exitosamente.
- `id` generado: `15aaaa06-2030-4bd4-94f6-287450f754b8`.

---

### 7) GET /productos/{id}
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos/$id" -Method Get
```
Resultado:
- Producto recuperado correctamente por ID.

---

### 8) PUT /productos/{id}
Payload de actualizacion:
```json
{
  "precio": 30,
  "stock": 45
}
```
Resultado:
- Producto actualizado exitosamente.
- Se reflejan cambios en `precio` y `stock`.

---

### 9) DELETE /productos/{id}
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos/$id" -Method Delete
```
Resultado:
- Producto eliminado exitosamente.

---

### 10) Verificacion post-eliminacion
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos/$id" -Method Get
```
Resultado:
- Error controlado esperado: `Producto ... no encontrado`.

---

## Incidencia tecnica relevante y resolucion

Durante pruebas, aparecio intermitentemente `Error al listar productos` despues de crear items.

Causa:
- Serializacion de tipos `Decimal` de DynamoDB al convertir a JSON.

Solucion implementada:
- Conversion recursiva de `Decimal` a tipos JSON-safe (`int`/`float`) en `productos.py`.

---

## Conclusiones
- CRUD de Productos validado end-to-end en local.
- Integracion Lambda + API Gateway local + DynamoDB funcional.
- Manejo de errores correcto para recursos inexistentes.
- Base estable para integrar Inventario, Compras y Ventas.

---

## Estado
- Fase 2 (Modulo Productos): Completada en validacion local.
- Siguiente fase recomendada: Modulo Inventarios.
