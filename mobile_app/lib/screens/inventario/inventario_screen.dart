import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _inventario = [];
  List<dynamic> _alertas = [];
  List<dynamic> _movimientos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.inventario), headers: ApiConfig.headers),
        http.get(Uri.parse(ApiConfig.inventarioAlertas), headers: ApiConfig.headers),
        http.get(Uri.parse(ApiConfig.inventarioMovimientos), headers: ApiConfig.headers),
      ]);
      setState(() {
        _inventario = jsonDecode(results[0].body)['inventario'] ?? [];
        _alertas = jsonDecode(results[1].body)['alertas'] ?? [];
        _movimientos = jsonDecode(results[2].body)['movimientos'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _registrarMovimiento() async {
    final productoIdCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();
    String tipo = 'entrada';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Movimiento de Inventario', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: tipo,
              dropdownColor: const Color(0xFF2A2A3E),
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: ['entrada', 'salida'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(color: Colors.white)))).toList(),
              onChanged: (v) => setS(() => tipo = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: productoIdCtrl,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: const InputDecoration(labelText: 'ID del Producto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final res = await http.post(
                    Uri.parse(ApiConfig.inventarioMovimiento),
                    headers: ApiConfig.headers,
                    body: jsonEncode({
                      'productoId': productoIdCtrl.text.trim(),
                      'tipo': tipo,
                      'cantidad': int.tryParse(cantidadCtrl.text.trim()) ?? 0,
                    }),
                  );
                  Navigator.pop(ctx);
                  if (res.statusCode == 201 || res.statusCode == 200) {
                    _cargar();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Movimiento registrado')));
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${res.statusCode}')));
                  }
                } catch (e) {
                  Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: const BackButton(),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar)],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF6C63FF),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          tabs: const [Tab(text: 'Stock'), Tab(text: 'Alertas'), Tab(text: 'Movimientos')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrarMovimiento,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: Text('Movimiento', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8AA0)),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                ]))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildStock(),
                    _buildAlertas(),
                    _buildMovimientos(),
                  ],
                ),
    );
  }

  Widget _buildStock() {
    if (_inventario.isEmpty) return _empty('Sin registros de inventario', Icons.warehouse_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventario.length,
      itemBuilder: (ctx, i) {
        final item = _inventario[i];
        final stock = (item['cantidadActual'] as num?)?.toInt() ?? 0;
        final color = stock <= 5 ? const Color(0xFFE74C3C) : stock <= 20 ? const Color(0xFFE67E22) : const Color(0xFF2ECC71);
        return _itemCard(
          icon: Icons.warehouse_rounded,
          iconColor: const Color(0xFFE67E22),
          title: item['productoId'] ?? 'Sin ID',
          subtitle: 'Stock actual: $stock',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('$stock', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ),
        );
      },
    );
  }

  Widget _buildAlertas() {
    if (_alertas.isEmpty) return _empty('Sin alertas de stock', Icons.check_circle_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alertas.length,
      itemBuilder: (ctx, i) {
        final a = _alertas[i];
        return _itemCard(
          icon: Icons.warning_rounded,
          iconColor: const Color(0xFFE74C3C),
          title: a['productoId'] ?? '',
          subtitle: 'Stock crítico: ${a['cantidadActual'] ?? 0}',
        );
      },
    );
  }

  Widget _buildMovimientos() {
    if (_movimientos.isEmpty) return _empty('Sin movimientos registrados', Icons.swap_horiz_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movimientos.length,
      itemBuilder: (ctx, i) {
        final m = _movimientos[i];
        final esEntrada = (m['tipo'] ?? '').toString().toLowerCase() == 'entrada';
        return _itemCard(
          icon: esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          iconColor: esEntrada ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
          title: m['tipo']?.toString().toUpperCase() ?? '',
          subtitle: 'Producto: ${m['productoId'] ?? ''} • Cant: ${m['cantidad'] ?? 0}',
        );
      },
    );
  }

  Widget _itemCard({required IconData icon, required Color iconColor, required String title, required String subtitle, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0))),
          ])),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: const Color(0xFF8A8AA0)),
      const SizedBox(height: 16),
      Text(msg, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
    ]),
  );
}
