import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ia_message.dart';
import 'local_nlp_service.dart';

/// Modos de inferencia disponibles.
enum IaMode {
  /// Parser local Dart (100% on-device, sin servidor).
  local,
  /// Ollama / Gemma 2B corriendo en EC2 (requiere conectividad).
  ollama,
}

class IaService {
  final _nlp = LocalNlpService();

  /// Modo activo. Por defecto: parser local (cumple requisito del profesor).
  IaMode modoActivo = IaMode.local;

  // ── Prompt para Ollama (modo remoto) ─────────────────────────────────────────
  static const String _systemPrompt = '''
Eres un asistente ERP. Convierte instrucciones a JSON. Sin texto extra.

SALIDA: Array JSON. Cada elemento: {"tool":"...","action":"...","payload":{...}}

HERRAMIENTAS VÁLIDAS:
cliente: crear, listar, eliminar
producto: crear, listar, actualizar_precio, eliminar
inventario: actualizar_stock, consultar_stock, listar_movimientos
compra: registrar, listar, recibir
venta: registrar, listar, cancelar

Si NO es una instrucción ERP:
[{"tool":"desconocido","action":"ninguna","payload":{"mensaje":"No es una instrucción ERP"}}]

EJEMPLOS:
"registrar cliente Juan Perez" →
[{"tool":"cliente","action":"crear","payload":{"nombre":"Juan","apellido":"Perez"}}]

"listar clientes y listar productos" →
[{"tool":"cliente","action":"listar","payload":{}},{"tool":"producto","action":"listar","payload":{}}]

"compra arroz proveedor ABC 10 kg 45 bolivianos" →
[{"tool":"compra","action":"registrar","payload":{"producto":"arroz","proveedor":"ABC","cantidad":10,"precio":45,"moneda":"bolivianos"}}]

"actualizar precio arroz a 15 bolivianos" →
[{"tool":"producto","action":"actualizar_precio","payload":{"producto":"arroz","precio":15}}]

"actualizar stock azucar 100" →
[{"tool":"inventario","action":"actualizar_stock","payload":{"producto":"azucar","cantidad":100}}]

"registrar cliente Maria Lopez y venta arroz 10 unidades 15 bolivianos" →
[{"tool":"cliente","action":"crear","payload":{"nombre":"Maria","apellido":"Lopez"}},{"tool":"venta","action":"registrar","payload":{"producto":"arroz","cantidad":10,"precio":15,"moneda":"bolivianos"}}]

Instrucción del usuario: ''';

  bool _modelWarmedUp = false;

  // ── Warm-up (solo Ollama) ─────────────────────────────────────────────────────
  Future<void> warmUp() async {
    if (_modelWarmedUp || modoActivo == IaMode.local) return;
    try {
      final modelName = ApiConfig.useLocalIA ? 'gemma-erp' : 'gemma:2b';
      await http
          .post(
            Uri.parse(ApiConfig.iaGenerate),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': modelName,
              'prompt': 'hola',
              'stream': false,
              'keep_alive': '10m',
              'options': {'num_predict': 1},
            }),
          )
          .timeout(const Duration(seconds: 30));
      _modelWarmedUp = true;
    } catch (_) {}
  }

  // ── Inferencia principal ──────────────────────────────────────────────────────

  /// Procesa [prompt] en lenguaje natural y retorna un [IaMessage] con el
  /// JSON estructurado listo para ejecutarse en el ERP.
  ///
  /// • Modo [IaMode.local]  → Parser Dart 100% on-device (sin red).
  /// • Modo [IaMode.ollama] → Gemma 2B vía Ollama en EC2.
  Future<IaMessage> inferir(String prompt) async {
    switch (modoActivo) {
      case IaMode.local:
        return _inferirLocal(prompt);
      case IaMode.ollama:
        return _inferirOllama(prompt);
    }
  }

  // ── Modo LOCAL ────────────────────────────────────────────────────────────────
  Future<IaMessage> _inferirLocal(String prompt) async {
    // Pequeño delay para dar sensación de "procesamiento"
    await Future.delayed(const Duration(milliseconds: 300));

    final jsonStr = _nlp.parsearAJson(prompt);
    return IaMessage.fromResponse(jsonStr);
  }

  // ── Modo OLLAMA ───────────────────────────────────────────────────────────────
  Future<IaMessage> _inferirOllama(String prompt) async {
    final fullPrompt = '$_systemPrompt$prompt\n\nJSON:';
    // gemma-erp = modelo local GGUF importado | gemma:2b = EC2
    final modelName = ApiConfig.useLocalIA ? 'gemma-erp' : 'gemma:2b';

    final res = await http
        .post(
          Uri.parse(ApiConfig.iaGenerate),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': modelName,
            'prompt': fullPrompt,
            'stream': false,
            'keep_alive': '10m',
            'options': {
              'temperature': 0.05,
              'top_p': 0.9,
              'num_predict': 512,
            },
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      String texto = (data['response'] ?? '').toString().trim();
      texto = _extraerJson(texto);
      return IaMessage.fromResponse(texto);
    }
    throw Exception('Error Ollama: ${res.statusCode} - ${res.body}');
  }

  // ── Health check ──────────────────────────────────────────────────────────────

  /// Verifica si el servidor Ollama (EC2) está disponible.
  Future<bool> checkHealth() async {
    if (modoActivo == IaMode.local) return true; // local siempre online
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.iaTags))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Extracción JSON (Ollama) ──────────────────────────────────────────────────
  String _extraerJson(String texto) {
    try {
      jsonDecode(texto);
      return texto;
    } catch (_) {}

    final arrStart = texto.indexOf('[');
    final arrEnd = texto.lastIndexOf(']');
    if (arrStart != -1 && arrEnd != -1 && arrEnd > arrStart) {
      final candidato = texto.substring(arrStart, arrEnd + 1);
      try {
        jsonDecode(candidato);
        return candidato;
      } catch (_) {}
    }

    final objStart = texto.indexOf('{');
    final objEnd = texto.lastIndexOf('}');
    if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
      final candidato = texto.substring(objStart, objEnd + 1);
      try {
        jsonDecode(candidato);
        return candidato;
      } catch (_) {}
    }

    return texto;
  }
}
