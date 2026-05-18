import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/cliente.dart';
import '../../services/clientes_service.dart';
import 'cliente_form_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _service = ClientesService();
  List<Cliente> _clientes = [];
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
      setState(() { _clientes = lista; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _eliminar(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar cliente', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('¿Eliminar a "${c.nombre}"?',
            style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
      await _service.eliminar(c.id);
      _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cliente eliminado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    }
  }

  List<Cliente> get _filtrados => _clientes
      .where((c) =>
          c.nombre.toLowerCase().contains(_search.toLowerCase()) ||
          c.email.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        leading: const BackButton(),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteFormScreen()));
          if (result == true) _cargar();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Nuevo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Buscar cliente...',
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
    if (_error != null) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8AA0)),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF8A8AA0)), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]),
    );
    if (_filtrados.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.people_alt_rounded, size: 56, color: Color(0xFF8A8AA0)),
        const SizedBox(height: 16),
        Text('Sin clientes', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
    );
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _filtrados.length,
        itemBuilder: (context, i) {
          final c = _filtrados[i];
          return _ClienteCard(
            cliente: c,
            onEdit: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: c)));
              if (result == true) _cargar();
            },
            onDelete: () => _eliminar(c),
          )
              .animate()
              .fadeIn(delay: (50 * i).ms, duration: 200.ms)
              .slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _ClienteCard extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ClienteCard({required this.cliente, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2ECC71).withOpacity(0.15),
            child: Text(
              cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF2ECC71)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cliente.nombre, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text(cliente.email, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0))),
              if (cliente.telefono.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(cliente.telefono, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0))),
              ],
            ]),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF2A2A3E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF6C63FF)), const SizedBox(width: 8), Text('Editar', style: GoogleFonts.inter(color: Colors.white))])),
              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFE74C3C)), const SizedBox(width: 8), Text('Eliminar', style: GoogleFonts.inter(color: Colors.white))])),
            ],
          ),
        ],
      ),
    );
  }
}
