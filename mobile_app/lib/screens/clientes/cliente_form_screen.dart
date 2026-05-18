import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/cliente.dart';
import '../../services/clientes_service.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ClientesService();
  bool _saving = false;

  late final TextEditingController _nombre;
  late final TextEditingController _email;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  late final TextEditingController _rfc;

  bool get _esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _direccion = TextEditingController(text: c?.direccion ?? '');
    _rfc = TextEditingController(text: c?.rfc ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose(); _email.dispose(); _telefono.dispose();
    _direccion.dispose(); _rfc.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_esEdicion) {
        await _service.actualizar(widget.cliente!.id, {
          'nombre': _nombre.text.trim(),
          'email': _email.text.trim(),
          'telefono': _telefono.text.trim(),
          'direccion': _direccion.text.trim(),
          'rfc': _rfc.text.trim(),
        });
      } else {
        await _service.crear(Cliente(
          id: '',
          nombre: _nombre.text.trim(),
          email: _email.text.trim(),
          telefono: _telefono.text.trim(),
          direccion: _direccion.text.trim(),
          rfc: _rfc.text.trim(),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_nombre, 'Nombre *', Icons.person_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 14),
            _field(_email, 'Email *', Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                }),
            const SizedBox(height: 14),
            _field(_telefono, 'Teléfono *', Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 14),
            _field(_direccion, 'Dirección', Icons.location_on_rounded),
            const SizedBox(height: 14),
            _field(_rfc, 'RFC / NIT', Icons.badge_rounded),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _guardar,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear cliente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
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
