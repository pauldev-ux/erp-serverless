# Resumen de Avance - ERP Serverless

**Fecha:** 22 de marzo de 2026  
**Proyecto:** ERP Serverless (AWS + SAM + Python)  
**Alumno:** Fernando

---

## Objetivo validado
Se validó el módulo de **Productos** con arquitectura serverless usando:
- AWS Lambda
- API Gateway (vía AWS SAM local)
- DynamoDB
- Docker Desktop para emulación local

---

## Entorno técnico confirmado
- AWS CLI configurado con perfil `erp-dev`
- SAM CLI funcionando
- Docker Desktop en ejecución (Engine running)
- WSL actualizado
- Proyecto compilando correctamente con `sam build --no-cached`
- API local levantada con `sam local start-api --profile erp-dev --region us-east-2`

---

## Evidencia de pruebas ejecutadas (CRUD Productos)

### 1) `GET /productos`
Resultado: correcto. Retorna lista de productos y total.

### 2) `POST /productos`
Resultado: correcto. Crea producto y retorna `id`.

### 3) `GET /productos/{id}`
Resultado: correcto. Retorna el producto creado por ID.

### 4) `PUT /productos/{id}`
Resultado: correcto. Actualiza precio y stock.

### 5) `DELETE /productos/{id}`
Resultado: correcto. Elimina el producto.

### 6) Verificación post-eliminación
`GET /productos/{id}` retorna: **producto no encontrado** (comportamiento esperado).

---

## Incidencias resueltas durante la sesión

1. **Docker no detectado por SAM**
   - Causa: WSL desactualizado / motor Docker no inicializado.
   - Solución: `wsl --update`, `wsl --shutdown`, abrir Docker y confirmar Engine running.

2. **Error de firma AWS (`InvalidSignatureException`)**
   - Causa: credenciales incorrectas en ejecución local.
   - Solución: uso explícito del perfil `erp-dev` y región `us-east-2`.

3. **Error de ruta (`Ruta no encontrada`)**
   - Causa: diferencias entre eventos API Gateway v1/v2.
   - Solución: ajuste del handler para soportar ambos formatos de evento.

4. **Error al listar productos tras crear**
   - Causa: serialización de `Decimal` en DynamoDB.
   - Solución: conversión recursiva a tipos JSON-safe en el handler.

---

## Estado de avance

- **Fase 1 (Configuración):** 100% completada
- **Fase 2 (Módulo Productos):** 100% validado en local
- **Siguiente fase recomendada:** Módulo Clientes

---

## Próximos pasos sugeridos

1. Desplegar stack a AWS con:
```powershell
sam deploy --guided --profile erp-dev
```

2. Replicar estructura CRUD para `clientes`.

3. Implementar lógica de inventario ligada a ventas/compras (disminuir/aumentar stock).

4. Agregar pruebas automatizadas básicas por endpoint.

---

## Conclusión
El módulo de Productos quedó funcional y comprobado de extremo a extremo en entorno local serverless. Se cuenta con base técnica estable para continuar con los demás módulos del ERP (clientes, inventario, compras y ventas).
