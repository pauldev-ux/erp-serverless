# Resumen de depuracion local (23 de marzo)

## Objetivo
Dejar funcionando el ERP serverless en local con SAM + Docker + DynamoDB local, evitando errores de credenciales, tablas y timeouts.

## Problemas detectados

1. Error de build por archivo bloqueado en .aws-sam/build.
2. Error InvalidSignatureException y luego UnrecognizedClientException al consultar DynamoDB.
3. Error ResourceNotFoundException (tabla no existente).
4. Error de sintaxis en PowerShell al ejecutar comandos multilinea.
5. Timeout intermitente en Lambda durante pruebas repetidas.

## Causa raiz
La API local estaba invocando funciones Lambda en contenedor, pero el acceso a DynamoDB no estaba apuntando de forma estable al endpoint local en todos los casos. Ademas, DynamoDB local se estaba iniciando de forma que no compartia tablas entre sesiones esperadas.

## Cambios en codigo

Se actualizaron handlers para usar endpoint configurable de DynamoDB:

- src/handlers/productos.py
- src/handlers/clientes.py
- src/handlers/inventario.py
- src/handlers/compras.py
- src/handlers/ventas.py

Logica aplicada:

- Si existe AWS_ENDPOINT_URL_DYNAMODB, se usa ese endpoint.
- Si no existe y se detecta AWS_SAM_LOCAL=true, se usa fallback a http://host.docker.internal:8000.

Tambien se agregaron variables en template.yaml para entorno local:

- AWS_ENDPOINT_URL_DYNAMODB
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_DEFAULT_REGION

## Flujo correcto (paso a paso)

1. Levantar DynamoDB local:

```powershell
docker run --rm -p 8000:8000 amazon/dynamodb-local -jar DynamoDBLocal.jar -sharedDb -inMemory
```

2. Crear tablas en local:

```powershell
$tables = "productos","clientes","inventario","compras","ventas"
foreach ($t in $tables) {
  aws dynamodb create-table --table-name $t --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url http://localhost:8000 --region us-east-2
}
```

3. Verificar tablas:

```powershell
aws dynamodb list-tables --endpoint-url http://localhost:8000 --region us-east-2
```

4. Build de SAM:

```powershell
sam build --no-cached; Write-Output "__EXIT_CODE:$LASTEXITCODE"
```

5. Levantar API local:

```powershell
sam local start-api
```

6. Probar endpoint productos:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```

## Checklist rapido de arranque diario (2 minutos)

Usa 3 consolas para no mezclar procesos.

1. Consola 1 (API SAM):

```powershell
cd d:\Universidad\Topicos\serverless\erp-serverless
sam build --no-cached
sam local start-api
```

2. Consola 2 (DynamoDB local):

```powershell
docker run --rm -p 8000:8000 amazon/dynamodb-local -jar DynamoDBLocal.jar -sharedDb -inMemory
```

3. Consola 3 (Smoke test rapido):

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```

4. Si responde 200, ya puedes continuar con pruebas de clientes, inventario y ventas.

5. Si responde error:
  - Verifica que DynamoDB local siga arriba (consola 2).
  - Verifica que SAM siga arriba (consola 1).
  - Si reinicias DynamoDB en memoria, recrea tablas.

## Arranque express (copiar y pegar)

Pega este bloque en una consola para iniciar DynamoDB local en segundo plano, compilar SAM, levantar la API y ejecutar una prueba rapida:

```powershell
Start-Process docker -ArgumentList 'run --rm -p 8000:8000 amazon/dynamodb-local -jar DynamoDBLocal.jar -sharedDb -inMemory' ; sam build --no-cached ; Start-Process pwsh -ArgumentList '-NoExit','-Command','sam local start-api' ; Start-Sleep -Seconds 6 ; Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```

Si devuelve respuesta 200, el entorno ya quedo arriba para continuar pruebas.

## Arranque express con validacion de tablas

Esta variante revisa tablas requeridas en DynamoDB local, crea las que falten, y luego ejecuta el smoke test:

```powershell
$required = "productos","clientes","inventario","compras","ventas" ; Start-Process docker -ArgumentList 'run --rm -p 8000:8000 amazon/dynamodb-local -jar DynamoDBLocal.jar -sharedDb -inMemory' ; Start-Sleep -Seconds 3 ; $existing = (aws dynamodb list-tables --endpoint-url http://localhost:8000 --region us-east-2 | ConvertFrom-Json).TableNames ; $missing = $required | Where-Object { $_ -notin $existing } ; foreach ($t in $missing) { aws dynamodb create-table --table-name $t --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url http://localhost:8000 --region us-east-2 | Out-Null } ; sam build --no-cached ; Start-Process pwsh -ArgumentList '-NoExit','-Command','sam local start-api' ; Start-Sleep -Seconds 6 ; Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```

Si no hay tablas faltantes, solo continua. Si faltan, las crea automaticamente.

## Validacion final lograda

1. Build exitoso (exit code 0).
2. GET /productos responde 200 con total=0.
3. POST /productos crea producto correctamente.
4. GET /productos devuelve total=1 con el producto creado.

## Evidencia de pruebas funcionales

### Crear producto

```powershell
$body = @{
  nombre = "Laptop Lenovo"
  descripcion = "14 pulgadas"
  precio = 3500
  stock = 8
  categoria = "Electronica"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Post -Body $body -ContentType "application/json"
```

### Listar productos

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/productos" -Method Get
```

## Notas importantes

1. Si aparece "connection refused", revisar que sam local start-api siga activo.
2. Si reinicias DynamoDB local con -inMemory, debes recrear tablas.
3. Si se detiene SAM con Ctrl+C y aparece traceback de watcher, es comun en Windows y no implica fallo de negocio.

## Estado actual

- Modulo productos validado localmente otra vez (GET y POST).
- Entorno local estabilizado para seguir con clientes, inventario y ventas.
- Fase 7 en progreso con mejoras de seguridad y configuracion de entorno.
