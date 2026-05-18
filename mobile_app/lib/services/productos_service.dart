import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/producto.dart';

class ProductosService {
  Future<List<Producto>> listar() async {
    final res = await http.get(
      Uri.parse(ApiConfig.productos),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['productos'] as List? ?? [];
      return lista.map((e) => Producto.fromJson(e)).toList();
    }
    throw Exception('Error al listar productos: ${res.statusCode}');
  }

  Future<Producto> obtener(String id) async {
    final res = await http.get(
      Uri.parse(ApiConfig.productoById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Producto.fromJson(data['producto']);
    }
    throw Exception('Producto no encontrado');
  }

  Future<Producto> crear(Producto producto) async {
    final res = await http.post(
      Uri.parse(ApiConfig.productos),
      headers: ApiConfig.headers,
      body: jsonEncode(producto.toJson()),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Producto.fromJson(data['producto']);
    }
    // El backend puede devolver { error: "string" } o { error: { message: "..." } }
    String msg = 'Error al crear producto (${res.statusCode})';
    try {
      final e = jsonDecode(res.body);
      if (e is Map) {
        final err = e['error'];
        if (err is String) msg = err;
        else if (err is Map) msg = err['message']?.toString() ?? msg;
        else msg = e['message']?.toString() ?? msg;
      }
    } catch (_) {}
    throw Exception(msg);
  }

  Future<Producto> actualizar(String id, Map<String, dynamic> campos) async {
    final res = await http.put(
      Uri.parse(ApiConfig.productoById(id)),
      headers: ApiConfig.headers,
      body: jsonEncode(campos),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Producto.fromJson(data['producto']);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error']?['message'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(String id) async {
    final res = await http.delete(
      Uri.parse(ApiConfig.productoById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar producto: ${res.statusCode}');
    }
  }
}
