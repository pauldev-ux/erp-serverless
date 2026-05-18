# Documentación: Configuración del Proyecto ERP Serverless

**Fecha:** Marzo 22, 2026  
**Objetivo:** Crear un ERP serverless en AWS con Python, Lambda, API Gateway y DynamoDB

---

## Parte 1: Preparación del Entorno

### 1.1 Verificar AWS CLI
```powershell
aws --version
```
**Resultado esperado:**
```
aws-cli/2.34.5 Python/3.13.11 Windows/10 exe/AMD64
```

**Explicación:**
- AWS CLI es la herramienta de línea de comandos para interactuar con AWS
- Permite crear, actualizar y eliminar recursos sin usar la consola web
- Versión 2.34.5 es actual y soporta todas las características necesarias

---

### 1.2 Crear cuenta IAM en AWS

#### Pasos en la consola AWS:
1. Ve a **IAM** → **Usuarios** → **Crear usuario**
2. Nombre: `erp-developer`
3. En permisos: **Asociar políticas directamente**
4. Busca y marca: **AdministratorAccess**
5. Crea el usuario

#### Crear Access Keys (credenciales CLI):
1. Entra al usuario `erp-developer`
2. Ve a **Credenciales de seguridad**
3. En **Claves de acceso**, clic en **Crear clave de acceso**
4. Elige: **Interfaz de línea de comandos (CLI)**
5. Marca confirmación
6. **Descarga el CSV** (única oportunidad de verlas)

**¿Por qué necesitamos esto?**
- Las Access Keys son como usuario/contraseña para AWS CLI
- El CSV contiene dos claves: Access Key ID y Secret Access Key
- Solo se muestran una vez, por eso descargamos el CSV

---

### 1.3 Configurar AWS CLI con Perfil

```powershell
# Eliminar configuración vieja (si la hay)
Remove-Item "$HOME\.aws\credentials" -ErrorAction SilentlyContinue
Remove-Item "$HOME\.aws\config" -ErrorAction SilentlyContinue

# Configurar nuevo perfil para este proyect
aws configure --profile erp-dev
```

**Qué ingresar (del CSV descargado):**
```
AWS Access Key ID [None]: AKIA....(copia del CSV)
AWS Secret Access Key [None]: ....(copia del CSV - clave larga)
Default region name [None]: us-east-2
Default output format [None]: json
```

**¿Por qué `--profile erp-dev`?**
- Permite tener múltiples cuentas AWS en la misma PC
- No borra configuraciones previas
- Al usar comandos AWS, especificas: `--profile erp-dev`

#### Verificar que funciona:
```powershell
aws sts get-caller-identity --profile erp-dev
```

**Resultado esperado (JSON):**
```json
{
    "UserId": "AIDAI...",
    "Account": "425182213169",
    "Arn": "arn:aws:iam::425182213169:user/erp-developer"
}
```

**Explicación:**
- `get-caller-identity` confirma que las credenciales son válidas
- Devuelve información de la cuenta y usuario autenticado
- Si sale error, las claves están incorrectas

---

## Parte 2: Instalar SAM CLI

```powershell
sam --version
```

**Resultado esperado:**
```
SAM CLI, version 1.156.0
```

**¿Qué es SAM?**
- **S**erverless **A**pplication **M**odel
- Framework oficial de AWS para infraestructura serverless
- Simplifica crear, probar y desplegar Lambda + API Gateway + DynamoDB
- Usa `template.yaml` para definir toda la infraestructura

---

## Parte 3: Crear Proyecto con SAM

### 3.1 Navegar a la carpeta
```powershell
cd D:\Universidad\Topicos\serverless
```

### 3.2 Inicializar proyecto SAM
```powershell
sam init
```

**Flujo de preguntas y respuestas:**

| Pregunta | Respuesta | Explicación |
|----------|-----------|-------------|
| Which template source? | `1` (AWS Quick Start Templates) | Usar plantillas oficiales de AWS |
| Choose template? | `7` (Serverless API) | API REST con rutas, ideal para ERP |
| Which runtime? | `6` (nodejs20.x) | Usaremos como base, luego cambiaremos a Python |
| X-Ray tracing? | `N` | No necesitamos tracing avanzado por ahora |
| CloudWatch Application Insights? | `N` | Costo adicional innecesario por ahora |
| Structured Logging JSON? | `Y` | Recomendado para logs limpios |
| Project name? | `erp-serverless` | Nombre de nuestro proyecto |

### 3.3 Estructura creada
```
erp-serverless/
├── src/                    # Código de funciones Lambda
├── events/                 # Archivos de prueba de eventos
├── __tests__/             # Tests unitarios
├── template.yaml          # Definición de infraestructura (SAM)
├── samconfig.toml         # Configuración de despliegue
├── package.json           # Dependencias Node.js
├── README.md              # Documentación
└── buildspec.yml          # Pipeline CI/CD
```

**Explicación de archivos clave:**
- **template.yaml**: Define funciones Lambda, API Gateway, permisos, tablas DynamoDB
- **samconfig.toml**: Configuración para `sam deploy` (región, bucket S3, etc.)
- **src/**: Contiene handlers (funciones) de Lambda

---

## Parte 4: Entrar al proyecto

```powershell
cd .\erp-serverless
dir
```

**Estructura final:**
```
Mode    LastWriteTime         Length  Name
----    -----                 ------  ----
d---    22/03/2026  0:41              __tests__
d---    22/03/2026  0:41              events
d---    22/03/2026  0:41              src
-a--    22/03/2026  0:41             14  .gitignore
-a--    22/03/2026  0:41            848  buildspec.yml
-a--    22/03/2026  0:41            231  env.json
-a--    22/03/2026  0:41            791  package.json
-a--    22/03/2026  0:41          10385  README.md
-a--    22/03/2026  0:41            706  samconfig.toml
-a--    22/03/2026  0:41           4396  template.yaml
```

---

## Próximes Pasos (Lo que viene)

### 1. Convertir a Python
- Modificar `template.yaml`: cambiar runtime a `python3.11`
- Eliminar archivos Node.js (`package.json`, `src/`)
- Crear `requirements.txt` con dependencias Python
- Crear `src/handlers/productos.py` con lógica del ERP

### 2. Crear módulo de Productos
Endpoints a implementar:
```
POST   /productos          - Crear producto
GET    /productos          - Listar productos
GET    /productos/{id}     - Obtener producto
PUT    /productos/{id}     - Actualizar producto
DELETE /productos/{id}     - Eliminar producto
```

### 3. Crear tabla DynamoDB
```yaml
ProductosTable:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: productos
    AttributeDefinitions:
      - AttributeName: id
        AttributeType: S
    KeySchema:
      - AttributeName: id
        KeyType: HASH
    BillingMode: PAY_PER_REQUEST
```

### 4. Probar localmente
```powershell
sam local start-api
```

### 5. Desplegar a AWS
```powershell
sam build
sam deploy --guide --profile erp-dev
```

---

## Información Importante

### AWS Free Tier (6 meses)
- ✅ 1,000,000 invocaciones Lambda/mes GRATIS
- ✅ 25 GB almacenamiento DynamoDB GRATIS
- ✅ 1 millón de solicitudes API Gateway GRATIS
- ✅ 400,000 GB-segundos compute Lambda GRATIS

**Conclusión:** El desarrollo y pruebas de todo el ERP están 100% gratis en estos 6 meses.

### Región: us-east-2 (Ohio)
- Seleccionada porque tiene buen soporte y costos bajos
- Todas nuestras configuraciones usan esta región

### Seguridad
- **NUNCA** compartas tus Access Keys
- **NUNCA** hagas commit de credenciales en Git
- Si expones una clave, desactívala inmediatamente en IAM
- Las claves se pueden regenerar sin problema

---

## Comandos Útiles para Referencia

```powershell
# Verificar versión SAM
sam --version

# Validar template.yaml
sam validate

# Compilar proyecto
sam build

# Probar API localmente (levanta servidor en puerto 3000)
sam local start-api

# Ver logs de función específica
sam logs -n NombreFuncion --tail

# Desplegar a AWS (guiado)
sam deploy --guided --profile erp-dev

# Desplegar actualización (sin preguntas)
sam deploy --profile erp-dev

# Listar todas las stacks desplegadas
aws cloudformation list-stacks --region us-east-2 --profile erp-dev
```

---

## Diagrama del Flujo Actual

```
┌─────────────────────────────────────────────┐
│ Mi PC (Windows)                             │
│ ┌──────────────────────────────────────────┐│
│ │ AWS CLI + SAM CLI + Python 3.11          ││
│ │ Credenciales: perfil erp-dev             ││
│ └──────────────────────────────────────────┘│
└──────────────┬──────────────────────────────┘
               │ sam build && sam deploy
               │
              AWS
            /  |  \
           /   |   \
          /    |    \
    Lambda  API GW  DynamoDB
    (Funciones)  (Rutas)  (BD)
```

---

## Checklist de Completitud

- [x] AWS CLI instalado y verificado
- [x] Cuenta IAM creada (erp-developer)
- [x] Access Keys descargadas y guardadas
- [x] Perfil AWS CLI configurado (erp-dev)
- [x] Credenciales probadas con `aws sts get-caller-identity`
- [x] SAM CLI instalado y verificado
- [x] Proyecto inicial creado con `sam init`
- [ ] Convertir a Python (próximo paso)
- [ ] Crear módulo de productos
- [ ] Crear tabla DynamoDB
- [ ] Probar endpoints localmente
- [ ] Desplegar a AWS

---

**Última actualización:** Marzo 22, 2026  
**Estado:** Fase 1 (Configuración) - COMPLETADA 60%
