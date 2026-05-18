import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/compra.dart';

class ComprasService {
  Future<List<Compra>> listar() async {
    final res = await http.get(
      Uri.parse(ApiConfig.compras),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['compras'] as List? ?? [];
      return lista.map((e) => Compra.fromJson(e)).toList();
    }
    throw Exception('Error al listar compras: ${res.statusCode}');
  }

  Future<Compra> obtener(String id) async {
    final res = await http.get(
      Uri.parse(ApiConfig.compraById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Compra.fromJson(data['compra']);
    }
    throw Exception('Compra no encontrada');
  }

  Future<Compra> crear(Map<String, dynamic> datos) async {
    final res = await http.post(
      Uri.parse(ApiConfig.compras),
      headers: ApiConfig.headers,
      body: jsonEncode(datos),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Compra.fromJson(data['compra']);
    }
    // Parsing robusto del error — el cuerpo puede ser Map, List o texto
    String msg = 'Error al crear compra (${res.statusCode})';
    try {
      final e = jsonDecode(res.body);
      if (e is Map) msg = e['error']?['message'] ?? e['message'] ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  Future<void> actualizarEstado(String id, String estado) async {
    final res = await http.put(
      Uri.parse(ApiConfig.compraEstado(id)),
      headers: ApiConfig.headers,
      body: jsonEncode({'estado': estado}),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar estado: ${res.statusCode}');
    }
  }

  Future<void> recibirCompra(String id) async {
    final res = await http.post(
      Uri.parse(ApiConfig.compraRecibir(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Error al recibir compra: ${res.statusCode}');
    }
  }
}
