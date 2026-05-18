"""
Servidor FastAPI para exponer el modelo Gemma 2B via HTTP REST.
La app Flutter se conecta a este endpoint para inferencia.

Instalar:
    pip install fastapi uvicorn llama-cpp-python

Correr:
    uvicorn ia_server:app --host 0.0.0.0 --port 8000 --reload

Desde emulador Android → acceder como http://10.0.2.2:8000
Desde dispositivo físico → usar la IP local de tu PC (ej: http://192.168.1.X:8000)
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from llama_cpp import Llama, LlamaGrammar
import os

# ── Configuración ─────────────────────────────────────────────────────────────
# Ruta absoluta al modelo .gguf (en "topicos mayo\Proyecto Modelo")
MODEL_PATH = os.getenv(
    "MODEL_PATH",
    r"D:\Universidad\Topicos\topicos mayo\Proyecto Modelo\gemma-2-2b-it-Q4_K_M.gguf"
)
GRAMMAR_PATH = os.getenv(
    "GRAMMAR_PATH",
    r"D:\Universidad\Topicos\topicos mayo\Proyecto Modelo\gramatica.gbnf"
)

app = FastAPI(
    title="ERP IA Server",
    description="Servidor de inferencia Gemma 2B para ERP Serverless",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Cargar modelo al inicio ───────────────────────────────────────────────────
print(f"🔄 Cargando modelo desde: {MODEL_PATH}")
llm = Llama(model_path=MODEL_PATH, verbose=False, n_ctx=2048)

with open(GRAMMAR_PATH, "r", encoding="utf-8") as f:
    GRAMMAR_STR = f.read()

SYSTEM = (
    "Eres un asistente de un sistema ERP. "
    "Modulos disponibles: cliente, producto, inventario, compra, venta. "
    "Acciones disponibles: "
    "crear_cliente, listar_clientes, eliminar_cliente, "
    "crear_producto, listar_productos, actualizar_precio, eliminar_producto, "
    "actualizar_stock, consultar_stock, "
    "registrar_compra, listar_compras, "
    "registrar_venta, listar_ventas. "
    "Responde SOLO con un JSON valido, sin texto adicional."
)

print("✅ Modelo cargado correctamente")


# ── Schemas ───────────────────────────────────────────────────────────────────
class PromptRequest(BaseModel):
    texto: str


class InferResponse(BaseModel):
    texto: str
    resultado: dict


# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {"status": "ok", "modelo": "gemma-2-2b-it-Q4_K_M"}


@app.post("/inferir", response_model=InferResponse)
def inferir(req: PromptRequest):
    if not req.texto.strip():
        raise HTTPException(status_code=400, detail="El texto no puede estar vacío")

    grammar = LlamaGrammar.from_string(GRAMMAR_STR)
    prompt = (
        f"<start_of_turn>user\n{SYSTEM}\n\nTexto: {req.texto}<end_of_turn>\n"
        f"<start_of_turn>model\n"
    )

    response = llm(prompt, grammar=grammar, max_tokens=200, temperature=0.0)
    json_text = response["choices"][0]["text"].strip()

    import json
    try:
        resultado = json.loads(json_text)
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail=f"El modelo generó JSON inválido: {json_text}")

    return InferResponse(texto=req.texto, resultado=resultado)


@app.post("/inferir/batch")
def inferir_batch(prompts: list[str]):
    """Enviar múltiples prompts en una sola llamada."""
    resultados = []
    for texto in prompts:
        grammar = LlamaGrammar.from_string(GRAMMAR_STR)
        prompt = (
            f"<start_of_turn>user\n{SYSTEM}\n\nTexto: {texto}<end_of_turn>\n"
            f"<start_of_turn>model\n"
        )
        resp = llm(prompt, grammar=grammar, max_tokens=200, temperature=0.0)
        import json
        try:
            resultado = json.loads(resp["choices"][0]["text"].strip())
            resultados.append({"texto": texto, "resultado": resultado, "ok": True})
        except Exception as e:
            resultados.append({"texto": texto, "error": str(e), "ok": False})
    return {"resultados": resultados, "total": len(resultados)}
