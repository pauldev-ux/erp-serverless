# Matriz Endpoint-Rol

## Regla general

- Cuando AUTH_ENABLED=false: no se exige rol.
- Cuando AUTH_ENABLED=true: se valida el header configurado en AUTH_HEADER (por defecto x-api-role).

## Modulos obligatorios

| Modulo | Endpoint | Metodo | Rol requerido |
|---|---|---|---|
| Productos | /productos | GET | publico |
| Productos | /productos | POST | admin |
| Productos | /productos/{id} | GET | publico |
| Productos | /productos/{id} | PUT | admin |
| Productos | /productos/{id} | DELETE | admin |
| Clientes | /clientes | GET | publico |
| Clientes | /clientes | POST | admin |
| Clientes | /clientes/{id} | GET | publico |
| Clientes | /clientes/{id} | PUT | admin |
| Clientes | /clientes/{id} | DELETE | admin |
| Inventario | /inventario | GET | publico |
| Inventario | /inventario/{productoId} | GET | publico |
| Inventario | /inventario/movimientos | GET | publico |
| Inventario | /inventario/alertas | GET | publico |
| Inventario | /inventario/movimiento | POST | admin |
| Ventas | /ventas | GET | publico |
| Ventas | /ventas | POST | admin o vendedor |
| Ventas | /ventas/{id} | GET | publico |
| Ventas | /ventas/{id}/cancelar | POST | admin |
| Ventas | /ventas/reportes | GET | admin |

## Modulo extra (no obligatorio)

| Modulo | Endpoint | Metodo | Rol requerido |
|---|---|---|---|
| Compras | /compras | GET | publico |
| Compras | /compras | POST | admin |
| Compras | /compras/{id} | GET | publico |
| Compras | /compras/{id}/estado | PUT | admin |
| Compras | /compras/{id}/recibir | POST | admin |
