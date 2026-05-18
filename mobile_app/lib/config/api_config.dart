/// Configuración central de la API
/// Cambia BASE_URL por tu URL real de AWS API Gateway
class ApiConfig {
  // ── URL base del API Gateway de AWS ─────────────────────────────────────────
  // Formato: https://XXXXXXX.execute-api.us-east-2.amazonaws.com/dev
  static const String BASE_URL =
      'https://wc4m2zupe2.execute-api.us-east-2.amazonaws.com/dev';

  // ── URL del servidor IA (Ollama en EC2 AWS) ────────────────────────────────
  // EC2: erp-ia-server | sa-east-1 | i-0044c74d4bf31ef23
  static const String IA_URL_EC2   = 'http://18.231.249.239:11434';

  // ── URL del servidor IA LOCAL (Ollama en tu PC con gemma-erp) ──────────────
  // IP WiFi de la PC: 192.168.0.7 — celular y PC deben estar en el mismo WiFi
  static const String IA_URL_LOCAL = 'http://192.168.0.7:11434';

  // ── Cambia a true para usar el modelo LOCAL, false para usar EC2 ────────────
  static const bool useLocalIA = true;

  static String get IA_URL => useLocalIA ? IA_URL_LOCAL : IA_URL_EC2;

  // ── Headers por defecto ──────────────────────────────────────────────────────
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'x-api-role': 'admin',
        'x-tenant-id': 'default',
      };

  // ── Endpoints ERP ────────────────────────────────────────────────────────────
  static String get productos => '$BASE_URL/productos';
  static String productoById(String id) => '$BASE_URL/productos/$id';

  static String get clientes => '$BASE_URL/clientes';
  static String clienteById(String id) => '$BASE_URL/clientes/$id';

  static String get inventario => '$BASE_URL/inventario';
  static String inventarioByProducto(String productoId) =>
      '$BASE_URL/inventario/$productoId';
  static String get inventarioMovimiento => '$BASE_URL/inventario/movimiento';
  static String get inventarioMovimientos => '$BASE_URL/inventario/movimientos';
  static String get inventarioAlertas => '$BASE_URL/inventario/alertas';

  static String get compras => '$BASE_URL/compras';
  static String compraById(String id) => '$BASE_URL/compras/$id';
  static String compraEstado(String id) => '$BASE_URL/compras/$id/estado';
  static String compraRecibir(String id) => '$BASE_URL/compras/$id/recibir';

  static String get ventas => '$BASE_URL/ventas';
  static String ventaById(String id) => '$BASE_URL/ventas/$id';
  static String ventaCancelar(String id) => '$BASE_URL/ventas/$id/cancelar';
  static String get ventasReportes => '$BASE_URL/ventas/reportes';

  // ── Endpoints Ollama (EC2) ───────────────────────────────────────────────────
  static String get iaGenerate => '$IA_URL/api/generate';
  static String get iaTags => '$IA_URL/api/tags';
  // Alias para compatibilidad
  static String get iaInferir => '$IA_URL/api/generate';
  static String get iaHealth => '$IA_URL/api/tags';
}
