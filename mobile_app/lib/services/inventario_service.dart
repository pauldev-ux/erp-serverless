import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/inventario.dart';

class InventarioService {
  /// Obtiene el stock actual de todos los productos.
  Future<List<Inventario>> listar() async {
    final res = await http.get(
      Uri.parse(ApiConfig.inventario),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['inventario'] as List? ?? [];
      return lista.map((e) => Inventario.fromJson(e)).toList();
    }
    throw Exception('Error al listar inventario: ${res.statusCode}');
  }

  /// Consulta el stock de un producto específico por su ID.
  Future<Inventario> consultarStock(String productoId) async {
    final res = await http.get(
      Uri.parse(ApiConfig.inventarioByProducto(productoId)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Inventario.fromJson(data['inventario'] ?? data);
    }
    throw Exception('Producto no encontrado en inventario');
  }

  /// Registra un movimiento de entrada o salida de stock.
  Future<void> registrarMovimiento({
    required String productoId,
    required String tipo,   // 'entrada' | 'salida'
    required int cantidad,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConfig.inventarioMovimiento),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'productoId': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = _tryParseError(res.body);
      throw Exception(err ?? 'Error al registrar movimiento: ${res.statusCode}');
    }
  }

  /// Actualiza el stock de un producto directamente (acción IA: actualizar_stock).
  Future<void> actualizarStock({
    required String productoId,
    required int cantidad,
  }) async {
    // Primero consultamos el stock actual para calcular la diferencia
    try {
      final actual = await consultarStock(productoId);
      final diferencia = cantidad - actual.cantidadActual;
      if (diferencia == 0) return;

      await registrarMovimiento(
        productoId: productoId,
        tipo: diferencia > 0 ? 'entrada' : 'salida',
        cantidad: diferencia.abs(),
      );
    } catch (_) {
      // Si no existe en inventario, hacemos entrada directa
      await registrarMovimiento(
        productoId: productoId,
        tipo: 'entrada',
        cantidad: cantidad,
      );
    }
  }

  /// Obtiene la lista de alertas de stock bajo.
  Future<List<Map<String, dynamic>>> listarAlertas() async {
    final res = await http.get(
      Uri.parse(ApiConfig.inventarioAlertas),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data['alertas'] ?? []);
    }
    throw Exception('Error al obtener alertas: ${res.statusCode}');
  }

  /// Obtiene el historial de movimientos de inventario.
  Future<List<MovimientoInventario>> listarMovimientos() async {
    final res = await http.get(
      Uri.parse(ApiConfig.inventarioMovimientos),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['movimientos'] as List? ?? [];
      return lista.map((e) => MovimientoInventario.fromJson(e)).toList();
    }
    throw Exception('Error al listar movimientos: ${res.statusCode}');
  }

  String? _tryParseError(String body) {
    try {
      final d = jsonDecode(body);
      return d['error']?['message'] ?? d['message'];
    } catch (_) {
      return null;
    }
  }
}
