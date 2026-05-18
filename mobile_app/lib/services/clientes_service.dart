import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/cliente.dart';

class ClientesService {
  Future<List<Cliente>> listar() async {
    final res = await http.get(
      Uri.parse(ApiConfig.clientes),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final lista = data['clientes'] as List? ?? [];
      return lista.map((e) => Cliente.fromJson(e)).toList();
    }
    throw Exception('Error al listar clientes: ${res.statusCode}');
  }

  Future<Cliente> obtener(String id) async {
    final res = await http.get(
      Uri.parse(ApiConfig.clienteById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Cliente.fromJson(data['cliente']);
    }
    throw Exception('Cliente no encontrado');
  }

  Future<Cliente> crear(Cliente cliente) async {
    final res = await http.post(
      Uri.parse(ApiConfig.clientes),
      headers: ApiConfig.headers,
      body: jsonEncode(cliente.toJson()),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Cliente.fromJson(data['cliente']);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error']?['message'] ?? 'Error al crear cliente');
  }

  Future<Cliente> actualizar(String id, Map<String, dynamic> campos) async {
    final res = await http.put(
      Uri.parse(ApiConfig.clienteById(id)),
      headers: ApiConfig.headers,
      body: jsonEncode(campos),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Cliente.fromJson(data['cliente']);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error']?['message'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(String id) async {
    final res = await http.delete(
      Uri.parse(ApiConfig.clienteById(id)),
      headers: ApiConfig.headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar cliente: ${res.statusCode}');
    }
  }
}
