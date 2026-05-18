# Despliegue Paso A Paso (AWS SAM)

Guia corta para pasar de entorno local a despliegue en AWS.

## 1) Pre-requisitos

- AWS CLI configurado (`aws configure`)
- SAM CLI instalado (`sam --version`)
- Docker instalado (para pruebas locales)
- Credenciales con permisos para CloudFormation, Lambda, API Gateway, IAM y DynamoDB

## 2) Validar template

Si en Windows tienes bloqueo de permisos en metadata de SAM, usa APPDATA local temporal:

```powershell
$env:APPDATA = Join-Path $PWD '.appdata'
New-Item -ItemType Directory -Path (Join-Path $env:APPDATA 'AWS SAM') -Force | Out-Null
sam validate --template template.yaml
```

## 3) Compilar

```powershell
sam build --no-cached
```

## 4) Desplegar por primera vez

```powershell
sam deploy --guided --profile erp-dev
```

Valores recomendados en el asistente:

- Stack Name: `erp-serverless`
- AWS Region: `us-east-2`
- Confirm changes before deploy: `N`
- Allow SAM CLI IAM role creation: `Y`
- Save arguments to samconfig.toml: `Y`

## 5) Configurar autenticacion en AWS (Cognito)

Antes de pruebas productivas, define variables de entorno en Lambda o template:

- `AUTH_ENABLED=true`
- `AUTH_PROVIDER=cognito` (o `hybrid`)
- `COGNITO_ROLE_ATTRIBUTE=custom:role`

En Cognito, asegura que el usuario tenga `custom:role` (por ejemplo `admin` o `vendedor`).

## 6) Verificacion post-deploy

1. Probar `GET /productos`.
2. Crear cliente y producto.
3. Crear venta y cancelar venta.
4. Verificar stock: 10 -> 8 -> 10.

## 7) Comandos utiles

```powershell
# Ver logs
sam logs -n VentasFunction --stack-name erp-serverless --tail

# Nuevo deploy (sin guided)
sam deploy --profile erp-dev
```
