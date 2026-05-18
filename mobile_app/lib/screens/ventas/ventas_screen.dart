import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/venta.dart';
import '../../services/ventas_service.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _service = VentasService();
  List<Venta> _ventas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final lista = await _service.listar();
      setState(() { _ventas = lista; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _nuevaVenta() async {
    final productoIdCtrl = TextEditingController();
    final clienteIdCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nueva Venta', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dField(productoIdCtrl, 'ID del Producto'),
            const SizedBox(height: 12),
            _dField(clienteIdCtrl, 'ID del Cliente (opcional)'),
            const SizedBox(height: 12),
            _dField(cantidadCtrl, 'Cantidad', TextInputType.number),
            const SizedBox(height: 12),
            _dField(precioCtrl, 'Precio unitario (Bs)', TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
              final precio = double.tryParse(precioCtrl.text.trim()) ?? 0;
              try {
                await _service.crear({
                  'productoId': productoIdCtrl.text.trim(),
                  if (clienteIdCtrl.text.trim().isNotEmpty) 'clienteId': clienteIdCtrl.text.trim(),
                  'cantidad': cantidad,
                  'precioUnitario': precio,
                  'total': cantidad * precio,
                  'moneda': 'Bs',
                });
                Navigator.pop(context);
                _cargar();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Venta registrada')));
              } catch (e) {
                Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  Widget _dField(TextEditingController ctrl, String label, [TextInputType? type]) => TextField(
    controller: ctrl,
    keyboardType: type,
    style: GoogleFonts.inter(color: Colors.white),
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        leading: const BackButton(),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaVenta,
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text('Nueva', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8AA0)),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0)), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                ]))
              : _ventas.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.point_of_sale_rounded, size: 56, color: Color(0xFF8A8AA0)),
                      const SizedBox(height: 16),
                      Text('Sin ventas registradas', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _ventas.length,
                        itemBuilder: (ctx, i) {
                          final v = _ventas[i];
                          final estadoColor = v.estado == 'completada'
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFE74C3C);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFFE74C3C), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Prod: ${v.productoId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (v.clienteId != null) Text('Cliente: ${v.clienteId}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0))),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: estadoColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Text(v.estadoLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: estadoColor)),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                _stat('${v.cantidad}', 'Cantidad', const Color(0xFF6C63FF)),
                                const SizedBox(width: 8),
                                _stat('Bs ${v.precioUnitario.toStringAsFixed(2)}', 'P. Unit', const Color(0xFF3498DB)),
                                const SizedBox(width: 8),
                                _stat('Bs ${v.total.toStringAsFixed(2)}', 'Total', const Color(0xFF2ECC71)),
                              ]),
                              if (v.estado == 'completada') ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await _service.cancelar(v.id);
                                      _cargar();
                                    },
                                    icon: const Icon(Icons.cancel_rounded, size: 16),
                                    label: const Text('Cancelar venta'),
                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE74C3C), side: const BorderSide(color: Color(0xFFE74C3C))),
                                  ),
                                ),
                              ],
                            ]),
                          )
                              .animate()
                              .fadeIn(delay: (50 * i).ms, duration: 200.ms)
                              .slideY(begin: 0.1, end: 0);
                        },
                      ),
                    ),
    );
  }

  Widget _stat(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF8A8AA0))),
      ]),
    ),
  );
}
