# Arquitectura ERP Serverless

## UML (PlantUML)

Diagrama UML de componentes para entender la arquitectura serverless completa.

```plantuml
@startuml
title ERP Serverless - Arquitectura UML (Componentes)

skinparam componentStyle rectangle
skinparam shadowing false
left to right direction

actor "Usuario / Cliente API" as User

node "AWS Cloud" {
    component "API Gateway\nREST API (stage: dev)" as APIGW

    package "AWS Lambda" {
        component "Lambda Productos" as LProductos
        component "Lambda Clientes" as LClientes
        component "Lambda Inventario" as LInventario
        component "Lambda Ventas" as LVentas
        component "Lambda Compras (extra)" as LCompras
    }

    database "DynamoDB\nproductos" as DProductos
    database "DynamoDB\nclientes" as DClientes
    database "DynamoDB\ninventario" as DInventario
    database "DynamoDB\nventas" as DVentas
    database "DynamoDB\ncompras" as DCompras

    component "Cognito User Pool\n(custom:role)" as Cognito
}

User --> APIGW : HTTP REST
User --> Cognito : Login / Token
Cognito --> APIGW : Claims de rol

APIGW --> LProductos
APIGW --> LClientes
APIGW --> LInventario
APIGW --> LVentas
APIGW --> LCompras

LProductos --> DProductos

LClientes --> DClientes

LInventario --> DInventario
LInventario --> DProductos

LVentas --> DVentas
LVentas --> DClientes
LVentas --> DProductos
LVentas --> DInventario

LCompras --> DCompras
LCompras --> DProductos
LCompras --> DInventario

note bottom of LVentas
Flujo clave:
1) validar cliente y stock
2) registrar venta
3) descontar/restaurar inventario
end note

@enduml
```

## Mermaid

Diagrama Mermaid listo para pegar/exportar.

```mermaid
flowchart LR
    U[Usuario / Cliente API] -->|HTTP REST| APIGW[API Gateway]

    APIGW --> P[Lambda Productos]
    APIGW --> C[Lambda Clientes]
    APIGW --> I[Lambda Inventario]
    APIGW --> V[Lambda Ventas]
    APIGW --> K[Lambda Compras extra]

    P --> T1[(DynamoDB Productos)]
    C --> T2[(DynamoDB Clientes)]
    I --> T1
    I --> T3[(DynamoDB Inventario)]
    V --> T1
    V --> T2
    V --> T3
    V --> T4[(DynamoDB Ventas)]
    K --> T1
    K --> T3
    K --> T5[(DynamoDB Compras)]

    U -->|Bearer Token| CG[Cognito User Pool]
    CG -->|custom:role| APIGW

    APIGW --> CW[CloudWatch Logs]
    P --> CW
    C --> CW
    I --> CW
    V --> CW
    K --> CW
```

## Resumen de flujo principal

1. Se crea cliente.
2. Se crea producto con stock inicial.
3. Se registra venta y baja stock.
4. Se cancela venta y se restaura stock.

Evidencia validada en local: `10 -> 8 -> 10`.

## UML de Secuencia (PlantUML)

Flujo completo: Cliente -> Producto -> Venta -> Cancelacion.

```plantuml
@startuml
title ERP Serverless - Secuencia de Flujo Principal

actor Usuario
participant "API Gateway" as APIGW
participant "Lambda Clientes" as LClientes
participant "Lambda Productos" as LProductos
participant "Lambda Ventas" as LVentas
participant "Lambda Inventario" as LInventario
database "DynamoDB Clientes" as DClientes
database "DynamoDB Productos" as DProductos
database "DynamoDB Ventas" as DVentas
database "DynamoDB Inventario" as DInventario

== 1) Crear Cliente ==
Usuario -> APIGW: POST /clientes
APIGW -> LClientes: evento HTTP
LClientes -> DClientes: PutItem(cliente)
DClientes --> LClientes: ok
LClientes --> APIGW: 201 cliente creado
APIGW --> Usuario: respuesta ok

== 2) Crear Producto ==
Usuario -> APIGW: POST /productos
APIGW -> LProductos: evento HTTP
LProductos -> DProductos: PutItem(producto)
DProductos --> LProductos: ok
LProductos --> APIGW: 201 producto creado
APIGW --> Usuario: respuesta ok

== 3) Crear Venta ==
Usuario -> APIGW: POST /ventas
APIGW -> LVentas: evento HTTP
LVentas -> DClientes: GetItem(cliente)
DClientes --> LVentas: cliente valido
LVentas -> DProductos: GetItem(producto)
DProductos --> LVentas: precio y stock
LVentas -> DInventario: PutItem(movimiento salida)
DInventario --> LVentas: movimiento ok
LVentas -> DProductos: UpdateItem(stock - cantidad)
DProductos --> LVentas: stock actualizado
LVentas -> DVentas: PutItem(venta)
DVentas --> LVentas: venta registrada
LVentas --> APIGW: 201 venta creada
APIGW --> Usuario: respuesta ok

== 4) Cancelar Venta ==
Usuario -> APIGW: POST /ventas/{id}/cancelar
APIGW -> LVentas: evento HTTP
LVentas -> DVentas: GetItem(venta)
DVentas --> LVentas: venta existente
LVentas -> DProductos: UpdateItem(stock + cantidad)
DProductos --> LVentas: stock restaurado
LVentas -> DInventario: PutItem(movimiento entrada)
DInventario --> LVentas: movimiento ok
LVentas -> DVentas: UpdateItem(estado=cancelada)
DVentas --> LVentas: venta cancelada
LVentas --> APIGW: 200 cancelacion exitosa
APIGW --> Usuario: respuesta ok

@enduml
```

## UML de Despliegue (PlantUML)

Vista de nodos AWS para presentacion.

```plantuml
@startuml
title ERP Serverless - UML de Despliegue AWS

skinparam shadowing false
left to right direction

node "Cliente Web / Postman" as Client

node "AWS Region us-east-2" {
    node "Amazon API Gateway\nREST API /dev" as ApiGw

    node "AWS Lambda" {
        artifact "productos-function" as FnProd
        artifact "clientes-function" as FnCli
        artifact "inventario-function" as FnInv
        artifact "ventas-function" as FnVen
        artifact "compras-function" as FnCom
    }

    database "DynamoDB productos" as TbProd
    database "DynamoDB clientes" as TbCli
    database "DynamoDB inventario" as TbInv
    database "DynamoDB ventas" as TbVen
    database "DynamoDB compras" as TbCom

    node "Amazon Cognito\nUser Pool" as Cognito
    node "Amazon CloudWatch Logs" as CwLogs
}

Client --> ApiGw : HTTPS requests
Client --> Cognito : Autenticacion
Cognito --> ApiGw : JWT / claims de rol

ApiGw --> FnProd
ApiGw --> FnCli
ApiGw --> FnInv
ApiGw --> FnVen
ApiGw --> FnCom

FnProd --> TbProd
FnCli --> TbCli
FnInv --> TbInv
FnInv --> TbProd
FnVen --> TbVen
FnVen --> TbCli
FnVen --> TbProd
FnVen --> TbInv
FnCom --> TbCom
FnCom --> TbProd
FnCom --> TbInv

FnProd --> CwLogs
FnCli --> CwLogs
FnInv --> CwLogs
FnVen --> CwLogs
FnCom --> CwLogs
ApiGw --> CwLogs

@enduml
```
