# 🧠 ¿Cómo decide el Asistente IA qué hacer?

> Documentación técnica del flujo de decisión del Asistente IA  
> **Proyecto:** ERP Serverless — Aplicación Móvil Flutter  
> **Modelo:** Gemma 2B corriendo en Ollama / AWS EC2

---

## Resumen en una línea

> El usuario escribe en **lenguaje natural** → Gemma 2B convierte la frase a **JSON estructurado** → el código ejecuta la **acción correcta en el backend AWS**.

---

## 🔵 Capa 1 — La IA decide (Gemma 2B)

### ¿Qué recibe el modelo?

El modelo **nunca recibe solo la frase del usuario**. Recibe un prompt completo construido así:

```
fullPrompt = _systemPrompt + frase_del_usuario + "\n\nJSON:"
```

### Estructura del `_systemPrompt` (la gramática)

**Archivo:** `lib/services/ia_service.dart` → constante `_systemPrompt`

```
┌──────────────────────────────────────────────────────────┐
│  1. ROL                                                  │
│     "Eres un asistente ERP. Convierte instrucciones      │
│      a JSON. Sin texto extra."                           │
├──────────────────────────────────────────────────────────┤
│  2. FORMATO DE SALIDA                                    │
│     Array JSON:                                          │
│     [{"tool":"...","action":"...","payload":{...}}]      │
├──────────────────────────────────────────────────────────┤
│  3. HERRAMIENTAS VÁLIDAS (gramática)                     │
│     cliente:   crear | listar | eliminar                 │
│     producto:  crear | listar | actualizar_precio        │
│     inventario: actualizar_stock | consultar_stock       │
│     compra:    registrar | listar | recibir              │
│     venta:     registrar | listar | cancelar             │
├──────────────────────────────────────────────────────────┤
│  4. EJEMPLOS FEW-SHOT (6 ejemplos)                       │
│     "registrar cliente Juan Perez" →                     │
│     [{"tool":"cliente","action":"crear",                 │
│       "payload":{"nombre":"Juan","apellido":"Perez"}}]   │
│                                                          │
│     "compra arroz 10 kg 45 bolivianos" →                 │
│     [{"tool":"compra","action":"registrar",              │
│       "payload":{"producto":"arroz","cantidad":10,...}}] │
├──────────────────────────────────────────────────────────┤
│  5. INSTRUCCIÓN DEL USUARIO                              │
│     "registrar venta de arroz 10 unidades Bs 16"         │
│  + sufijo: "\n\nJSON:"                                   │
└──────────────────────────────────────────────────────────┘
```

### ¿Por qué Gemma escoge bien? — 3 técnicas

| Técnica | Valor | Efecto |
|---|---|---|
| **Few-shot learning** | 6 ejemplos en el prompt | El modelo aprende el patrón por analogía, sin entrenamiento extra |
| **Temperature** | `0.05` (muy bajo) | El modelo es determinista, no "improvisa" respuestas aleatorias |
| **Sufijo `JSON:`** | Al final del prompt | Fuerza al modelo a continuar con JSON puro, no con texto libre |

---

## 🟢 Capa 2 — El código decide cómo ejecutarlo

Una vez que Gemma responde, **la IA ya terminó su trabajo**. El código toma el control:

### Paso a paso

```
Texto de Gemma (puede tener texto extra antes/después del JSON)
        │
        ▼ _extraerJson()   [ia_service.dart]
        │  Busca [ ... ] primero, luego { ... }
        │  Valida que sea JSON válido
        │
        ▼ IaMessage.fromResponse()   [ia_message.dart]
        │  Convierte el JSON string a lista de Map<String,dynamic>
        │
        ▼ ToolActionExecutor.ejecutar()   [tool_action_executor.dart]
        │
        ├── switch(tool)
        │     "cliente"    → _ejecutarCliente(action, payload)
        │     "producto"   → _ejecutarProducto(action, payload)
        │     "inventario" → _ejecutarInventario(action, payload)
        │     "compra"     → _ejecutarCompra(action, payload)
        │     "venta"      → _ejecutarVenta(action, payload)
        │
        └── switch(action)   [dentro de cada _ejecutar*()]
              "registrar"        → busca productoId → POST al API Gateway
              "listar"           → GET al API Gateway
              "actualizar_stock" → busca producto → PUT inventario
              "consultar_stock"  → busca producto → GET inventario
              ...
                    │
                    ▼
              AWS API Gateway → Lambda → DynamoDB
                    │
                    ▼
              ToolActionResult(exito: true/false, mensaje: "...")
                    │
                    ▼
              Burbuja verde ✅ o roja ❌ en la pantalla
```

---

## 🟣 Flujo completo de decisión — Diagrama

```
Usuario escribe:
"Registrar venta de arroz cantidad 10 precio Bs 16"
                    │
                    ▼
        ┌─────────────────────┐
        │    ia_service.dart  │
        │    inferir(prompt)  │
        │                     │
        │  fullPrompt =       │
        │  _systemPrompt +    │
        │  "venta arroz..." + │
        │  "\n\nJSON:"        │
        └────────┬────────────┘
                 │  HTTP POST
                 ▼
        ┌─────────────────────┐
        │  Gemma 2B en EC2    │
        │  (Ollama server)    │
        │                     │
        │  Compara con        │
        │  ejemplos del       │
        │  _systemPrompt      │
        │                     │
        │  Responde:          │
        │  [{"tool":"venta",  │
        │   "action":         │
        │   "registrar",      │
        │   "payload":{       │
        │   "producto":       │
        │   "arroz",          │
        │   "cantidad":"10",  │
        │   "precio":"16"}}]  │
        └────────┬────────────┘
                 │
                 ▼
        _extraerJson() → extrae el [...] del texto
                 │
                 ▼
        IaMessage.fromResponse() → parsea a lista de acciones
                 │
                 ▼
        ToolActionExecutor
        switch("venta") → _ejecutarVenta()
        switch("registrar"):
          1. Busca "arroz" en lista de productos → productoId
          2. Calcula total = cantidad × precio
          3. POST /ventas con {productoId, cantidad, precioUnitario, total}
                 │
                 ▼
        AWS API Gateway → Lambda → DynamoDB guarda la venta
                 │
                 ▼
        ✅ "Venta de 'Arroz' registrada — 10 unidades a Bs 16. Total: Bs 160."
```

---

## 📁 Archivos involucrados en la decisión

| Archivo | Rol |
|---|---|
| `lib/services/ia_service.dart` | Define `_systemPrompt` (la gramática) y llama a Gemma |
| `lib/models/ia_message.dart` | Parsea el JSON de Gemma a objetos Dart |
| `lib/services/tool_action_executor.dart` | Ejecuta la acción: busca datos, llama al backend |
| `lib/services/productos_service.dart` | Resuelve nombre de producto → ID real en DynamoDB |
| `lib/services/ventas_service.dart` | POST /ventas al API Gateway |
| `lib/screens/ia/ia_chat_screen.dart` | Muestra el resultado al usuario en pantalla |

---

## 🎯 ¿Por qué este enfoque y no otro?

| Alternativa | Problema | Nuestra solución |
|---|---|---|
| Reglas programadas (if/else) | Inflexible, no entiende lenguaje natural | Gemma 2B con few-shot learning |
| GPT-4 / Claude | Costoso, requiere API key, datos salen del servidor | Gemma 2B local en EC2 (privado y gratuito) |
| Entrenamiento fine-tuning | Requiere datos etiquetados y tiempo de entrenamiento | Few-shot: solo 6 ejemplos en el prompt |
| Un solo endpoint para todo | Sin estructura, difícil de mantener | JSON estructurado con tool + action + payload |

---

## 🔑 Conceptos clave para la presentación

- **Few-shot learning:** El modelo aprende el patrón de entrada→salida solo con ejemplos en el prompt, sin reentrenamiento.
- **Temperature 0.05:** Controla la "creatividad" del modelo. Cerca de 0 = muy predecible y consistente.
- **Tool Action:** Patrón de diseño donde la IA genera una "intención" estructurada que el código puede ejecutar de forma segura.
- **Multi-intención:** Un solo mensaje puede generar múltiples actions que se ejecutan en secuencia.
