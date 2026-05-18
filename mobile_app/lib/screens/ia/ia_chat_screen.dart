import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/ia_message.dart';
import '../../services/ia_service.dart';
import '../../services/tool_action_executor.dart';

class IaChatScreen extends StatefulWidget {
  const IaChatScreen({super.key});

  @override
  State<IaChatScreen> createState() => _IaChatScreenState();
}

class _IaChatScreenState extends State<IaChatScreen> {
  final _service = IaService();
  final _executor = ToolActionExecutor();
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<IaMessage> _messages = [];
  bool _iaOnline = false;
  bool _checkingHealth = true;
  bool _cargando = false;
  bool _autoEjecutar = true; // Ejecuta automáticamente en el ERP sin confirmación

  // Prompts de ejemplo del proyecto
  static const _ejemplos = [
    // ── Preguntas múltiples (multi-intent) ──
    'Registrar cliente Maria Lopez y registrar venta de arroz 10 unidades a 15 bolivianos',
    'Compra de azucar proveedor ABC 50 kg a 18 bolivianos y actualizar stock de arroz a 200',
    'Listar clientes y listar productos',
    // ── Preguntas simples ──
    'Registrar cliente nombre Maria apellido Lopez',
    'Crear producto azucar precio Bs 20',
    'Listar todos los productos',
    'Actualizar precio del arroz a Bs 15',
    'Actualizar stock de azucar cantidad 100',
    'Registrar compra de azucar cantidad 50 precio Bs 18 moneda Bs',
    'Registrar venta de arroz cantidad 10 precio Bs 16 moneda Bs',
    'Listar todas las ventas',
    'Consultar stock del arroz',
  ];

  @override
  void initState() {
    super.initState();
    // Modo local por defecto — corre 100% en el dispositivo móvil
    _service.modoActivo = IaMode.local;
    _checkHealth();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final ok = await _service.checkHealth();
    setState(() { _iaOnline = ok; _checkingHealth = false; });
  }

  Future<void> _enviar([String? textoFijo]) async {
    final texto = (textoFijo ?? _ctrl.text).trim();
    if (texto.isEmpty) return;

    _ctrl.clear();
    setState(() { _messages.add(IaMessage.user(texto)); });

    // En modo Ollama pre-filtramos con keywords; en modo local el NLP valida solo
    if (_service.modoActivo == IaMode.ollama && !_esComandoErp(texto)) {
      setState(() {
        _messages.add(IaMessage.error(
          'Solo proceso instrucciones ERP. Prueba: "registrar cliente", "listar productos", "actualizar stock"...'
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() { _cargando = true; _messages.add(IaMessage.loading()); });
    _scrollToBottom();

    try {
      final respuesta = await _service.inferir(texto);
      setState(() {
        _messages.removeLast();
        _messages.add(respuesta);
        _cargando = false;
      });
      _scrollToBottom();

      if (respuesta.hasStructuredData && mounted) {
        await _ofrecerEjecucion(respuesta);
      } else if (!respuesta.hasStructuredData && mounted) {
        setState(() {
          _messages.add(IaMessage.error(
            'No reconocí una instrucción ERP válida. Prueba: "registrar cliente Juan Lopez", "listar productos", "compra de arroz 10 unidades a 15 bolivianos".'
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      final esTimeout = e.toString().contains('TimeoutException') ||
          e.toString().contains('Future not completed');
      setState(() {
        _messages.removeLast();
        _cargando = false;
        _messages.add(IaMessage.error(
          esTimeout
              ? '⏱️ El modelo tardó demasiado. Intenta de nuevo.'
              : e.toString(),
        ));
      });
      _scrollToBottom();
    }
  }

  /// Pre-filtro ERP para modo Ollama (en modo local siempre retorna true).
  bool _esComandoErp(String texto) {
    final t = texto.toLowerCase();
    const keywords = [
      'registrar', 'crear', 'listar', 'mostrar', 'ver', 'actualizar',
      'eliminar', 'borrar', 'consultar', 'compra', 'venta', 'producto',
      'cliente', 'inventario', 'stock', 'precio', 'proveedor', 'recibir',
      'cancelar', 'reporte', 'movimiento', 'alerta',
    ];
    return keywords.any((k) => t.contains(k));
  }

  /// Ejecuta acciones ERP: auto-ejecución directa si [_autoEjecutar] está ON.
  Future<void> _ofrecerEjecucion(IaMessage msg) async {
    final acciones = msg.parsedJsonList ??
        (msg.parsedJson != null ? [msg.parsedJson!] : <Map<String, dynamic>>[]);
    if (acciones.isEmpty) return;

    if (_autoEjecutar) {
      // ── Ejecución directa sin diálogo (modo demo) ──
      await _ejecutarAcciones(acciones);
      return;
    }

    // ── Diálogo de confirmación (modo manual) ──
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.electric_bolt_rounded, color: Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(
            acciones.length > 1 ? 'Ejecutar ${acciones.length} acciones' : 'Ejecutar acción',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          )),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Confirmas ejecutar en el ERP?',
                style: GoogleFonts.inter(color: const Color(0xFF8A8AA0), fontSize: 13)),
            const SizedBox(height: 12),
            ...acciones.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: Text('${a['tool']} → ${a['action']}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF8A8AA0))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Ejecutar', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _ejecutarAcciones(acciones);
  }

  /// Envía las acciones al API Gateway de AWS y muestra los resultados en el chat.
  Future<void> _ejecutarAcciones(List<Map<String, dynamic>> acciones) async {
    if (!mounted) return;
    setState(() { _cargando = true; _messages.add(IaMessage.loading()); });
    _scrollToBottom();
    try {
      final resultados = await _executor.ejecutarLista(acciones);
      setState(() { _messages.removeLast(); _cargando = false; });
      for (final r in resultados) {
        setState(() {
          _messages.add(r.exito ? IaMessage.resultado(r.mensaje) : IaMessage.error(r.mensaje));
        });
      }
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _cargando = false;
        _messages.add(IaMessage.error('Error al ejecutar: $e'));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _limpiar() {
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🤖 '),
          Flexible(
            child: Text('Asistente IA',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          _checkingHealth
              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _iaOnline ? const Color(0xFF1A3A2A) : const Color(0xFF3A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (_iaOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                            color: _iaOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(_iaOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _iaOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C))),
                  ]),
                ),
        ]),
        leading: const BackButton(),
        actions: [
          // Selector de modo: Local (on-device) ↔ Ollama (EC2)
          GestureDetector(
            onTap: () {
              setState(() {
                _service.modoActivo = _service.modoActivo == IaMode.local
                    ? IaMode.ollama
                    : IaMode.local;
                _iaOnline = _service.modoActivo == IaMode.local;
              });
              _checkHealth();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _service.modoActivo == IaMode.local
                    ? const Color(0xFF1A3A2A)
                    : const Color(0xFF1A1A3A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _service.modoActivo == IaMode.local
                      ? const Color(0xFF2ECC71).withOpacity(0.5)
                      : const Color(0xFF6C63FF).withOpacity(0.5),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _service.modoActivo == IaMode.local
                      ? Icons.phone_android_rounded
                      : Icons.cloud_rounded,
                  size: 12,
                  color: _service.modoActivo == IaMode.local
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFF6C63FF),
                ),
                const SizedBox(width: 4),
                Text(
                  _service.modoActivo == IaMode.local ? 'Local' : 'Ollama',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _service.modoActivo == IaMode.local
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFF6C63FF),
                  ),
                ),
              ]),
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _limpiar, tooltip: 'Limpiar chat'),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _checkHealth, tooltip: 'Verificar conexión'),
        ],
      ),
      body: Column(
        children: [
          // El banner offline solo aplica en modo Ollama (EC2)
          if (_service.modoActivo == IaMode.ollama && !_iaOnline && !_checkingHealth)
            _buildOfflineBanner(),
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildChat(),
          ),
          // Ocultar chips cuando el teclado está abierto para evitar overflow
          if (!teclado) _buildEjemplos(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF3A1A1A),
      child: Row(children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFE74C3C), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          _service.modoActivo == IaMode.local
              ? 'Modelo corriendo localmente en el dispositivo. Sin conexión requerida.'
              : 'Servidor Ollama (EC2) no disponible. Verifica que esté activo.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE74C3C)),
        )),
      ]),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        const Text('🤖', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        Text(
          _service.modoActivo == IaMode.local
              ? 'Asistente ERP — NLP Local'
              : 'Asistente ERP con Gemma 2B',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _service.modoActivo == IaMode.local
              ? '🟢 Modelo corriendo en el dispositivo. Sin servidor externo.'
              : 'Escribe en lenguaje natural y Gemma 2B generará el JSON para el ERP.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A8AA0)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Módulos disponibles:',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF8A8AA0))),
            const SizedBox(height: 8),
            ...[
              ('🧑', 'cliente', 'crear, listar, eliminar'),
              ('📦', 'producto', 'crear, listar, actualizar precio'),
              ('🏭', 'inventario', 'actualizar stock, consultar stock'),
              ('🛒', 'compra', 'registrar, listar, recibir'),
              ('💰', 'venta', 'registrar, listar, cancelar'),
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text(t.$1, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text('${t.$2} → ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6C63FF))),
                Expanded(child: Text(t.$3, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A8AA0)))),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        return _MessageBubble(message: msg)
            .animate()
            .fadeIn(duration: 200.ms)
            .slideY(begin: 0.2, end: 0, duration: 200.ms);
      },
    );
  }

  Widget _buildEjemplos() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _ejemplos.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _enviar(_ejemplos[i]),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
            ),
            child: Text(
              _ejemplos[i],
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A8AA0)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _enviar(),
            decoration: InputDecoration(
              hintText: 'Escribe un prompt en lenguaje natural...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A8AA0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _cargando ? null : _enviar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _cargando
                  ? [const Color(0xFF4A4A6A), const Color(0xFF4A4A6A)]
                  : [const Color(0xFF6C63FF), const Color(0xFF9B3FBF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _cargando
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final IaMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
            const SizedBox(width: 12),
            Text('Procesando...', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A8AA0))),
          ]),
        ),
      );
    }

    final isUser = message.role == MessageRole.user;
    final isError = message.role == MessageRole.error;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B3FBF)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text, style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
        ),
      );
    }

    if (isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 16),
            const SizedBox(width: 8),
            Flexible(child: Text(message.text, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE74C3C)))),
          ]),
        ),
      );
    }

    // Burbuja verde de resultado de ejecución exitosa
    if (message.role == MessageRole.resultado) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71), size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message.text,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF2ECC71), fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      );
    }

    // Respuesta del modelo IA
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.hasStructuredData) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(children: [
                Icon(
                  message.hasMultipleActions
                      ? Icons.auto_awesome_mosaic_rounded
                      : Icons.auto_awesome_rounded,
                  color: const Color(0xFF6C63FF),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  message.actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: message.text)),
                  child: const Icon(Icons.copy_rounded, color: Color(0xFF8A8AA0), size: 14),
                ),
              ]),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: message.parsedJsonList != null
                ? _buildJsonListView(message.parsedJsonList!)
                : message.parsedJson != null
                    ? _buildJsonView(message.parsedJson!)
                    : Text(
                        message.text,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                      ),
          ),
        ]),
      ),
    );
  }

  /// Muestra múltiples tarjetas de acción numeradas (multi-intención).
  Widget _buildJsonListView(List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.asMap().entries.map((entry) {
        final idx = entry.key;
        final json = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (list.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Acción ${idx + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A8AA0),
                    ),
                  ),
                ]),
              ),
            _buildJsonView(json),
            if (idx < list.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.white.withOpacity(0.07), height: 1),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildJsonView(Map<String, dynamic> json) {
    final tool = json['tool'] ?? '';
    final action = json['action'] ?? '';
    final payload = json['payload'] as Map<String, dynamic>? ?? {};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _jsonRow('tool', tool, const Color(0xFF3498DB)),
      const SizedBox(height: 4),
      _jsonRow('action', action, const Color(0xFF2ECC71)),
      if (payload.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF13131F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('payload:',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: const Color(0xFF8A8AA0))),
            const SizedBox(height: 4),
            ...payload.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: '  ${e.key}: ',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, color: const Color(0xFF8A8AA0))),
                      TextSpan(
                          text: '"${e.value}"',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, color: const Color(0xFFE67E22))),
                    ]),
                  ),
                )),
          ]),
        ),
      ],
    ]);
  }

  Widget _jsonRow(String key, dynamic value, Color valueColor) => RichText(
        text: TextSpan(children: [
          TextSpan(
              text: '$key: ',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, color: const Color(0xFF8A8AA0))),
          TextSpan(
              text: '"$value"',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: valueColor,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

