import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/compra.dart';
import '../../services/compras_service.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final _service = ComprasService();
  List<Compra> _compras = [];
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
      setState(() { _compras = lista; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _nuevaCompra() async {
    final productoIdCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nueva Orden de Compra',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(productoIdCtrl, 'ID del Producto'),
            const SizedBox(height: 12),
            _field(proveedorCtrl, 'Proveedor (opcional)'),
            const SizedBox(height: 12),
            _field(cantidadCtrl, 'Cantidad', TextInputType.number),
            const SizedBox(height: 12),
            _field(precioCtrl, 'Precio unitario (Bs)', TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
              final precio = double.tryParse(precioCtrl.text.trim()) ?? 0;
              try {
                await _service.crear({
                  'productoId': productoIdCtrl.text.trim(),
                  'cantidad': cantidad,
                  'precioUnitario': precio,
                  'total': cantidad * precio,
                  'moneda': 'Bs',
                  if (proveedorCtrl.text.trim().isNotEmpty)
                    'proveedor': proveedorCtrl.text.trim(),
                });
                if (mounted) Navigator.pop(context);
                _cargar();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Orden de compra creada')));
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $e')));
                }
              }
            },
            child: const Text('Crear Orden'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, [TextInputType? type]) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(labelText: label),
      );

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'recibido': return const Color(0xFF2ECC71);
      case 'cancelado': return const Color(0xFFE74C3C);
      default: return const Color(0xFFF39C12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaCompra,
        icon: const Icon(Icons.shopping_cart_rounded),
        label: Text('Nueva Orden', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF9B59B6),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8AA0)),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                ]))
              : _compras.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shopping_cart_rounded, size: 56,
                          color: Color(0xFF8A8AA0)),
                      const SizedBox(height: 16),
                      Text('Sin órdenes de compra',
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Toca + para crear una orden',
                          style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _compras.length,
                        itemBuilder: (ctx, i) {
                          final c = _compras[i];
                          final color = _estadoColor(c.estado);
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
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9B59B6).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.shopping_cart_rounded,
                                      color: Color(0xFF9B59B6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Prod: ${c.productoId}',
                                      style: GoogleFonts.inter(
                                          fontSize: 13, fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (c.proveedor != null)
                                    Text('Proveedor: ${c.proveedor}',
                                        style: GoogleFonts.inter(
                                            fontSize: 12, color: const Color(0xFF8A8AA0))),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(c.estadoLabel,
                                      style: GoogleFonts.inter(
                                          fontSize: 11, fontWeight: FontWeight.w600,
                                          color: color)),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                _stat('${c.cantidad}', 'Cantidad', const Color(0xFF6C63FF)),
                                const SizedBox(width: 8),
                                _stat('Bs ${c.precioUnitario.toStringAsFixed(2)}', 'P. Unit',
                                    const Color(0xFF3498DB)),
                                const SizedBox(width: 8),
                                _stat('Bs ${c.total.toStringAsFixed(2)}', 'Total',
                                    const Color(0xFF2ECC71)),
                              ]),
                              if (c.estado == 'pendiente') ...[
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await _service.recibirCompra(c.id);
                                        _cargar();
                                      },
                                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                                      label: const Text('Recibir'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2ECC71),
                                        side: const BorderSide(color: Color(0xFF2ECC71)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await _service.actualizarEstado(c.id, 'cancelado');
                                        _cargar();
                                      },
                                      icon: const Icon(Icons.cancel_rounded, size: 16),
                                      label: const Text('Cancelar'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFE74C3C),
                                        side: const BorderSide(color: Color(0xFFE74C3C)),
                                      ),
                                    ),
                                  ),
                                ]),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.inter(
            fontSize: 10, color: const Color(0xFF8A8AA0))),
      ]),
    ),
  );
}
