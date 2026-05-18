import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/producto.dart';
import '../../services/productos_service.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductosService();
  bool _saving = false;

  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late final TextEditingController _stock;
  late final TextEditingController _categoria;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _precio = TextEditingController(text: p != null ? p.precio.toString() : '');
    _stock = TextEditingController(text: p != null ? p.stock.toString() : '');
    _categoria = TextEditingController(text: p?.categoria ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose(); _descripcion.dispose();
    _precio.dispose(); _stock.dispose(); _categoria.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_esEdicion) {
        await _service.actualizar(widget.producto!.id, {
          'nombre': _nombre.text.trim(),
          'descripcion': _descripcion.text.trim(),
          'precio': double.parse(_precio.text.trim()),
          'stock': int.parse(_stock.text.trim()),
          'categoria': _categoria.text.trim(),
        });
      } else {
        final p = Producto(
          id: '',
          nombre: _nombre.text.trim(),
          descripcion: _descripcion.text.trim(),
          precio: double.parse(_precio.text.trim()),
          stock: int.parse(_stock.text.trim()),
          categoria: _categoria.text.trim().isEmpty ? 'Sin categoría' : _categoria.text.trim(),
        );
        await _service.crear(p);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Producto' : 'Nuevo Producto'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_nombre, 'Nombre *', Icons.inventory_2_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 14),
            _field(_descripcion, 'Descripción', Icons.description_rounded),
            const SizedBox(height: 14),
            _field(_precio, 'Precio (Bs) *', Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (double.tryParse(v.trim()) == null) return 'Número inválido';
                  return null;
                }),
            const SizedBox(height: 14),
            _field(_stock, 'Stock *', Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (int.tryParse(v.trim()) == null) return 'Entero inválido';
                  return null;
                }),
            const SizedBox(height: 14),
            _field(_categoria, 'Categoría', Icons.category_rounded),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _guardar,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8A8AA0), size: 20),
      ),
    );
  }
}
