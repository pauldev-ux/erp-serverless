# Resumen de Pruebas - Modulo Clientes

Fecha: 22 de marzo de 2026  
Proyecto: ERP Serverless (AWS SAM + Python)

---

## Objetivo
Validar el CRUD completo del modulo Clientes en entorno local con AWS SAM + Docker + DynamoDB.

---

## Entorno usado
- API local: `sam local start-api --profile erp-dev --region us-east-2`
- Tabla DynamoDB: `clientes`
- Region: `us-east-2`
- Perfil AWS CLI: `erp-dev`

---

## Evidencia de ejecucion

### 1) Crear tabla DynamoDB
Comando ejecutado:
```powershell
aws dynamodb create-table \
  --table-name clientes \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2 \
  --profile erp-dev
```
Resultado:
- Tabla creada correctamente (`TableStatus: CREATING`).
- ARN confirmado: `arn:aws:dynamodb:us-east-2:425182213169:table/clientes`.

### 2) GET /clientes
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/clientes" -Method Get
```
Resultado:
- Respuesta correcta con `total = 0` y lista vacia.

### 3) POST /clientes
Payload usado:
```json
{
  "nombre": "Juan Perez",
  "email": "juan@correo.com",
  "telefono": "5512345678",
  "direccion": "CDMX",
  "rfc": "JUAP900101AA1"
}
```
Resultado:
- Cliente creado exitosamente.
- `id` generado y devuelto en respuesta.

### 4) GET /clientes/{id}
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/clientes/$id" -Method Get
```
Resultado:
- Cliente recuperado correctamente por ID.

### 5) PUT /clientes/{id}
Payload de actualizacion:
```json
{
  "telefono": "5599998888",
  "direccion": "Guadalajara"
}
```
Resultado:
- Cliente actualizado exitosamente.
- Se reflejan los nuevos datos en la respuesta.

### 6) DELETE /clientes/{id}
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/clientes/$id" -Method Delete
```
Resultado:
- Cliente eliminado exitosamente.

### 7) Verificacion post-eliminacion
Comando:
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/clientes/$id" -Method Get
```
Resultado:
- Error controlado esperado: `Cliente ... no encontrado`.

---

## Conclusiones
- CRUD de Clientes validado end-to-end en local.
- Integracion Lambda + API Gateway local + DynamoDB funcional.
- Manejo de errores correcto para recursos inexistentes.

---

## Estado
- Fase 3 (Modulo Clientes): Completada en validacion local.
- Siguiente fase recomendada: Modulo Inventarios.
