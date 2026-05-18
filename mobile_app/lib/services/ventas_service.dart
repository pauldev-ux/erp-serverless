import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/venta.dart';

class VentasService {
  Future<List<Venta>> listar() async {
    final res = await http.get(
      Uri.parse(ApiConfig.ventas),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['ventas'] as List? ?? [];
      return lista.map((e) => Venta.fromJson(e)).toList();
    }
    throw Exception('Error al listar ventas: ${res.statusCode}');
  }

  Future<Venta> obtener(String id) async {
    final res = await http.get(
      Uri.parse(ApiConfig.ventaById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Venta.fromJson(data['venta']);
    }
    throw Exception('Venta no encontrada');
  }

  Future<Venta> crear(Map<String, dynamic> datos) async {
    final res = await http.post(
      Uri.parse(ApiConfig.ventas),
      headers: ApiConfig.headers,
      body: jsonEncode(datos),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Venta.fromJson(data['venta']);
    }
    // Parsing robusto del error
    String msg = 'Error al crear venta (${res.statusCode})';
    try {
      final e = jsonDecode(res.body);
      if (e is Map) msg = e['error']?['message'] ?? e['message'] ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  Future<void> cancelar(String id) async {
    final res = await http.post(
      Uri.parse(ApiConfig.ventaCancelar(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Error al cancelar venta: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> reportes() async {
    final res = await http.get(
      Uri.parse(ApiConfig.ventasReportes),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener reportes');
  }
}
