import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/producto.dart';
import '../../services/productos_service.dart';
import 'producto_form_screen.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final _service = ProductosService();
  List<Producto> _productos = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final lista = await _service.listar();
      setState(() { _productos = lista; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _eliminar(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar producto', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('¿Eliminar "${p.nombre}"?',
            style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.eliminar(p.id);
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Producto eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    }
  }

  List<Producto> get _filtrados => _productos
      .where((p) =>
          p.nombre.toLowerCase().contains(_search.toLowerCase()) ||
          p.categoria.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar productos'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductoFormScreen()),
          );
          if (result == true) _cargar();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text('Registrar producto', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Consultar productos...',
                prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF8A8AA0)),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_filtrados.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _filtrados.length,
        itemBuilder: (context, i) {
          final p = _filtrados[i];
          return _ProductoCard(
            producto: p,
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
              );
              if (result == true) _cargar();
            },
            onDelete: () => _eliminar(p),
          )
              .animate()
              .fadeIn(delay: (50 * i).ms, duration: 200.ms)
              .slideX(begin: 0.1, end: 0, duration: 200.ms);
        },
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8AA0)),
        const SizedBox(height: 16),
        Text('Error de conexión', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0), fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_rounded, size: 56, color: Color(0xFF8A8AA0)),
        const SizedBox(height: 16),
        Text('Sin productos', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Agrega tu primer producto', style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
      ],
    ),
  );
}

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductoCard({required this.producto, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final stockColor = producto.stock <= 5
        ? const Color(0xFFE74C3C)
        : producto.stock <= 20
            ? const Color(0xFFE67E22)
            : const Color(0xFF2ECC71);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF3498DB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto.nombre, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text(producto.categoria, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0))),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF2A2A3E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2AB7CA)), const SizedBox(width: 8), Text('Editar', style: GoogleFonts.inter(color: Colors.white))])),
                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFE74C3C)), const SizedBox(width: 8), Text('Eliminar', style: GoogleFonts.inter(color: Colors.white))])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Bs ${producto.precio.toStringAsFixed(2)}', 'Precio', const Color(0xFF6C63FF)),
              const SizedBox(width: 12),
              _stat('${producto.stock}', 'Stock', stockColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A8AA0))),
          ],
        ),
      ),
    );
  }
}
