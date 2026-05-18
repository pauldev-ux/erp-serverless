import 'clientes_service.dart';
import 'productos_service.dart';
import 'inventario_service.dart';
import 'compras_service.dart';
import 'ventas_service.dart';
import '../models/cliente.dart';
import '../models/producto.dart';

/// Resultado de ejecutar un Tool Action.
class ToolActionResult {
  final bool exito;
  final String mensaje;
  final Map<String, dynamic>? data;

  const ToolActionResult({
    required this.exito,
    required this.mensaje,
    this.data,
  });

  factory ToolActionResult.ok(String msg, [Map<String, dynamic>? data]) =>
      ToolActionResult(exito: true, mensaje: msg, data: data);

  factory ToolActionResult.error(String msg) =>
      ToolActionResult(exito: false, mensaje: msg);
}

/// Servicio que ejecuta Tool Actions generados por el modelo IA.
/// Mapea {tool, action, payload} → llamada real al API Gateway.
class ToolActionExecutor {
  final _clientes = ClientesService();
  final _productos = ProductosService();
  final _inventario = InventarioService();
  final _compras = ComprasService();
  final _ventas = VentasService();

  /// Ejecuta un Tool Action y retorna el resultado.
  Future<ToolActionResult> ejecutar(Map<String, dynamic> action) async {
    final tool = (action['tool'] ?? '').toString().toLowerCase();
    final act = (action['action'] ?? '').toString().toLowerCase();
    final payload = Map<String, dynamic>.from(action['payload'] ?? {});

    try {
      switch (tool) {
        case 'cliente':
          return await _ejecutarCliente(act, payload);
        case 'producto':
          return await _ejecutarProducto(act, payload);
        case 'inventario':
          return await _ejecutarInventario(act, payload);
        case 'compra':
          return await _ejecutarCompra(act, payload);
        case 'venta':
          return await _ejecutarVenta(act, payload);
        default:
          return ToolActionResult.error('Tool desconocido: "$tool"');
      }
    } catch (e) {
      return ToolActionResult.error(_limpiarError(e.toString()));
    }
  }

  /// Ejecuta múltiples Tool Actions en secuencia.
  Future<List<ToolActionResult>> ejecutarLista(
      List<Map<String, dynamic>> actions) async {
    final resultados = <ToolActionResult>[];
    for (final action in actions) {
      resultados.add(await ejecutar(action));
    }
    return resultados;
  }

  // ── CLIENTES ────────────────────────────────────────────────────────────────
  Future<ToolActionResult> _ejecutarCliente(
      String action, Map<String, dynamic> p) async {
    switch (action) {
      case 'crear':
        final nombre = (p['nombre'] ?? p['name'] ?? '').toString().trim();
        final apellido = (p['apellido'] ?? p['lastname'] ?? '').toString().trim();

        // Email placeholder si el usuario no lo especificó
        String email = (p['email'] ?? '').toString().trim();
        if (email.isEmpty) {
          final n = nombre.toLowerCase().replaceAll(' ', '');
          final a = apellido.toLowerCase().replaceAll(' ', '');
          email = a.isNotEmpty ? '$n.$a@erp.local' : '$n@erp.local';
        }

        // Teléfono placeholder si el usuario no lo especificó (backend lo requiere)
        String telefono = (p['telefono'] ?? p['phone'] ?? p['tel'] ?? '').toString().trim();
        if (telefono.isEmpty) telefono = '00000000';

        final cliente = Cliente(
          id: '',
          nombre: nombre,
          apellido: apellido,
          email: email,
          telefono: telefono,
        );
        final creado = await _clientes.crear(cliente);
        return ToolActionResult.ok(
          '✅ Cliente "${creado.nombre} ${creado.apellido}" creado exitosamente.',
          creado.toJson(),
        );

      case 'listar':
        final lista = await _clientes.listar();
        return ToolActionResult.ok(
          '📋 ${lista.length} cliente(s) encontrado(s).',
          {'total': lista.length, 'clientes': lista.map((c) => c.toJson()).toList()},
        );

      case 'eliminar':
        final id = p['id'] ?? '';
        if (id.isEmpty) return ToolActionResult.error('Se requiere el ID del cliente.');
        await _clientes.eliminar(id);
        return ToolActionResult.ok('🗑️ Cliente eliminado correctamente.');

      default:
        return ToolActionResult.error('Acción de cliente no reconocida: "$action"');
    }
  }

  // ── PRODUCTOS ────────────────────────────────────────────────────────────────
  Future<ToolActionResult> _ejecutarProducto(
      String action, Map<String, dynamic> p) async {
    switch (action) {
      case 'crear':
        // El backend valida que stock exista y sea > 0 (Node.js trata 0 como falsy)
        final stockVal = p['stock'] != null ? _toInt(p['stock']) : 0;
        final producto = Producto(
          id: '',
          nombre: (p['nombre'] ?? p['name'] ?? p['producto'] ?? '').toString().trim(),
          descripcion: (p['descripcion'] ?? '').toString(),
          precio: _toDouble(p['precio']),
          stock: stockVal,          // 0 es válido — backend envía stock:0 al crear
          categoria: (p['categoria'] ?? 'General').toString(),
        );
        final creado = await _productos.crear(producto);
        return ToolActionResult.ok(
          '✅ Producto "${creado.nombre}" creado a Bs ${creado.precio} (stock inicial: ${creado.stock}).',
          creado.toJson(),
        );

      case 'listar':
        final lista = await _productos.listar();
        return ToolActionResult.ok(
          '📦 ${lista.length} producto(s) encontrado(s).',
          {'total': lista.length, 'productos': lista.map((p) => p.toJson()).toList()},
        );

      case 'actualizar_precio':
        // Busca producto por nombre con normalización de tildes y búsqueda fuzzy
        final nombreBusq = _normalizar(p['producto'] ?? p['nombre'] ?? '');
        if (nombreBusq.isEmpty) return ToolActionResult.error('Indica el nombre del producto.');
        final precio = _toDouble(p['precio']);
        final listaPrec = await _productos.listar();
        Producto? prod;
        // 1. Búsqueda exacta normalizada
        try {
          prod = listaPrec.firstWhere(
            (pr) => _normalizar(pr.nombre) == nombreBusq,
          );
        } catch (_) {}
        // 2. Búsqueda parcial normalizada
        prod ??= listaPrec.cast<Producto?>().firstWhere(
          (pr) => _normalizar(pr!.nombre).contains(nombreBusq) ||
                  nombreBusq.contains(_normalizar(pr.nombre)),
          orElse: () => null,
        );
        if (prod == null) {
          final nombres = listaPrec.map((p) => p.nombre).join(', ');
          return ToolActionResult.error(
            'Producto "${p['producto'] ?? p['nombre']}" no encontrado.\nProductos disponibles: $nombres'
          );
        }
        await _productos.actualizar(prod.id, {'precio': precio});
        return ToolActionResult.ok(
          '✅ Precio de "${prod.nombre}" actualizado a Bs $precio.',
        );

      case 'eliminar':
        final id = p['id'] ?? '';
        if (id.isEmpty) return ToolActionResult.error('Se requiere el ID del producto.');
        await _productos.eliminar(id);
        return ToolActionResult.ok('🗑️ Producto eliminado correctamente.');

      default:
        return ToolActionResult.error('Acción de producto no reconocida: "$action"');
    }
  }

  // ── INVENTARIO ───────────────────────────────────────────────────────────────
  Future<ToolActionResult> _ejecutarInventario(
      String action, Map<String, dynamic> p) async {
    switch (action) {
      case 'actualizar_stock':
        final nombreStk = _normalizar(p['producto'] ?? p['nombre'] ?? '');
        if (nombreStk.isEmpty) return ToolActionResult.error('Indica el nombre del producto.');
        final cantidad = _toInt(p['cantidad']);

        // Buscar producto por nombre con normalización
        final productos = await _productos.listar();
        Producto? prodStk;
        try {
          prodStk = productos.firstWhere(
            (pr) => _normalizar(pr.nombre) == nombreStk,
          );
        } catch (_) {}
        prodStk ??= productos.cast<Producto?>().firstWhere(
          (pr) => _normalizar(pr!.nombre).contains(nombreStk) ||
                  nombreStk.contains(_normalizar(pr.nombre)),
          orElse: () => null,
        );
        if (prodStk == null) {
          final nombres = productos.map((p) => p.nombre).join(', ');
          return ToolActionResult.error(
            'Producto "${p['producto'] ?? p['nombre']}" no encontrado.\nProductos disponibles: $nombres'
          );
        }
        await _inventario.actualizarStock(
          productoId: prodStk.id,
          cantidad: cantidad,
        );
        return ToolActionResult.ok(
          '✅ Stock de "${prodStk.nombre}" actualizado a $cantidad unidades.',
        );

      case 'consultar_stock':
        final nombreCons = _normalizar(p['producto'] ?? p['nombre'] ?? '');
        if (nombreCons.isEmpty) return ToolActionResult.error('Indica el nombre del producto.');
        final productosAll = await _productos.listar();
        Producto? prodCons;
        try {
          prodCons = productosAll.firstWhere(
            (pr) => _normalizar(pr.nombre) == nombreCons,
          );
        } catch (_) {}
        prodCons ??= productosAll.cast<Producto?>().firstWhere(
          (pr) => _normalizar(pr!.nombre).contains(nombreCons) ||
                  nombreCons.contains(_normalizar(pr.nombre)),
          orElse: () => null,
        );
        if (prodCons == null) {
          final nombres = productosAll.map((p) => p.nombre).join(', ');
          return ToolActionResult.error(
            'Producto "${p['producto'] ?? p['nombre']}" no encontrado.\nProductos disponibles: $nombres'
          );
        }
        final inv = await _inventario.consultarStock(prodCons.id);
        return ToolActionResult.ok(
          '📊 Stock de "${prodCons.nombre}": ${inv.cantidadActual} unidades.',
          inv.toJson(),
        );

      case 'listar_movimientos':
        final movs = await _inventario.listarMovimientos();
        return ToolActionResult.ok(
          '📋 ${movs.length} movimiento(s) registrado(s).',
          {'total': movs.length},
        );

      case 'listar_alertas':
        final alertas = await _inventario.listarAlertas();
        return ToolActionResult.ok(
          '⚠️ ${alertas.length} alerta(s) de stock bajo.',
          {'total': alertas.length},
        );

      default:
        return ToolActionResult.error('Acción de inventario no reconocida: "$action"');
    }
  }

  // ── COMPRAS ──────────────────────────────────────────────────────────────────
  Future<ToolActionResult> _ejecutarCompra(
      String action, Map<String, dynamic> p) async {
    switch (action) {
      case 'registrar':
        // ⚠️ El backend Lambda espera:
        // { "proveedor": "...", "productos": [{ "productoId": "uuid", "cantidad": N, "precioUnitario": N }] }
        final nombreProdC = (p['producto'] ?? p['nombre'] ?? '').toString().trim();
        if (nombreProdC.isEmpty) return ToolActionResult.error('Se requiere el nombre del producto.');

        // Buscar el producto por nombre para obtener su ID real de DynamoDB
        final listaProdC = await _productos.listar();
        final normNombreC = _normalizar(nombreProdC);
        final prodC = listaProdC.cast<Producto?>().firstWhere(
          (pr) => _normalizar(pr!.nombre) == normNombreC ||
                  _normalizar(pr.nombre).contains(normNombreC) ||
                  normNombreC.contains(_normalizar(pr.nombre)),
          orElse: () => null,
        );
        if (prodC == null) {
          final nombres = listaProdC.map((x) => x.nombre).join(', ');
          return ToolActionResult.error(
            'Producto "$nombreProdC" no encontrado.\nDisponibles: $nombres\n\nCrea el producto primero: "Crear producto $nombreProdC precio Bs XX"');
        }

        // Proveedor (requerido por el backend)
        final proveedorC = (p['proveedor'] ?? p['supplier'] ?? '').toString().trim();

        // Construir payload EXACTO que espera el Lambda:
        // { proveedor, productos: [{ productoId, cantidad, precioUnitario }] }
        final cantC = _toInt(p['cantidad']);
        final precC = _toDouble(p['precio']);
        final datosC = <String, dynamic>{
          'proveedor': proveedorC.isNotEmpty ? proveedorC : 'Sin especificar',
          'productos': [
            {
              'productoId':     prodC.id,     // ID real de DynamoDB ✅
              'cantidad':       cantC,
              'precioUnitario': precC,
            }
          ],
          'observaciones': p['observaciones'] ?? '',
        };
        final compra = await _compras.crear(datosC);
        return ToolActionResult.ok(
          '✅ Compra de "${prodC.nombre}" — $cantC uds a Bs $precC c/u. Total: ${(cantC * precC).toStringAsFixed(2)}.',
          compra.toJson(),
        );

      case 'listar':
        final lista = await _compras.listar();
        return ToolActionResult.ok(
          '🛒 ${lista.length} compra(s) encontrada(s).',
          {'total': lista.length},
        );

      case 'recibir':
        final id = p['id'] ?? '';
        if (id.isEmpty) return ToolActionResult.error('Se requiere el ID de la compra.');
        await _compras.recibirCompra(id);
        return ToolActionResult.ok('✅ Compra marcada como recibida.');

      default:
        return ToolActionResult.error('Acción de compra no reconocida: "$action"');
    }
  }

  // ── VENTAS ───────────────────────────────────────────────────────────────────
  Future<ToolActionResult> _ejecutarVenta(
      String action, Map<String, dynamic> p) async {
    switch (action) {
      case 'registrar':
        // ⚠️ Lambda ventas requiere:
        // { "clienteId": "uuid" (OBLIGATORIO), "productos": [{"productoId":"uuid","cantidad":N}] }
        // El precio lo lee directamente de DynamoDB — NO se envía en el body

        // 1. Buscar producto por nombre → obtener su ID
        final nombreProdV = (p['producto'] ?? p['nombre'] ?? '').toString().trim();
        if (nombreProdV.isEmpty) return ToolActionResult.error('Se requiere el nombre del producto.');

        final listaProdV = await _productos.listar();
        final normNombreV = _normalizar(nombreProdV);
        final prodV = listaProdV.cast<Producto?>().firstWhere(
          (pr) => _normalizar(pr!.nombre) == normNombreV ||
                  _normalizar(pr.nombre).contains(normNombreV) ||
                  normNombreV.contains(_normalizar(pr.nombre)),
          orElse: () => null,
        );
        if (prodV == null) {
          final nombres = listaProdV.map((x) => x.nombre).join(', ');
          return ToolActionResult.error(
            'Producto "$nombreProdV" no encontrado.\nDisponibles: $nombres');
        }

        // 2. Resolver clienteNombre → clienteId (REQUERIDO por el Lambda)
        String? clienteIdV = (p['clienteId'] ?? p['cliente_id'])?.toString();
        if (clienteIdV == null || clienteIdV.isEmpty) {
          final nomCliV = (p['clienteNombre'] ?? p['customer'] ?? '').toString().trim();
          if (nomCliV.isNotEmpty) {
            final cliV = await _resolverClientePorNombre(nomCliV);
            clienteIdV = cliV?.id;
          }
        }
        if (clienteIdV == null || clienteIdV.isEmpty) {
          // Si no hay cliente, listar clientes y pedir que especifique
          final clientes = await _clientes.listar();
          if (clientes.isEmpty) {
            return ToolActionResult.error(
              'Para registrar una venta necesitas un cliente.\n'
              'Primero crea uno: "Registrar cliente Juan Perez"');
          }
          final nombresC = clientes.map((c) => '${c.nombre} ${c.apellido}').join(', ');
          return ToolActionResult.error(
            'Para la venta necesitas indicar el cliente.\n'
            'Ejemplo: "Venta de ${prodV.nombre} ${ p['cantidad'] ?? 1} unidades para Juan Perez"\n'
            'Clientes disponibles: $nombresC');
        }

        // 3. Construir payload EXACTO que espera el Lambda
        final cantV = _toInt(p['cantidad']);
        final datosV = <String, dynamic>{
          'clienteId': clienteIdV,       // OBLIGATORIO ✅
          'productos': [
            {
              'productoId': prodV.id,    // ID real de DynamoDB ✅
              'cantidad':   cantV,        // El precio lo lee el Lambda de DynamoDB
            }
          ],
        };
        final venta = await _ventas.crear(datosV);
        final nomCliLabel = (p['clienteNombre'] ?? p['customer'] ?? '').toString().trim();
        final cliMsgV = nomCliLabel.isNotEmpty ? ' para "$nomCliLabel"' : '';
        return ToolActionResult.ok(
          '✅ Venta de "${prodV.nombre}"$cliMsgV — $cantV uds. registrada.',
          venta.toJson(),
        );

      case 'listar':
        final lista = await _ventas.listar();
        return ToolActionResult.ok(
          '💰 ${lista.length} venta(s) encontrada(s).',
          {'total': lista.length},
        );

      case 'cancelar':
        final id = p['id'] ?? '';
        if (id.isEmpty) return ToolActionResult.error('Se requiere el ID de la venta.');
        await _ventas.cancelar(id);
        return ToolActionResult.ok('✅ Venta cancelada correctamente.');

      case 'reporte':
        final rep = await _ventas.reportes();
        return ToolActionResult.ok('📊 Reporte generado.', rep);

      default:
        return ToolActionResult.error('Acción de venta no reconocida: "$action"');
    }
  }

  /// Busca un cliente en el ERP por nombre o apellido (búsqueda fuzzy normalizada).
  /// Si no lo encuentra, retorna null — la operación igual se registra sin cliente vinculado.
  Future<Cliente?> _resolverClientePorNombre(String nombreBusq) async {
    if (nombreBusq.isEmpty) return null;
    final norm = _normalizar(nombreBusq);
    try {
      final lista = await _clientes.listar();
      // 1. Coincidencia exacta en nombre o apellido
      for (final c in lista) {
        if (_normalizar(c.nombre) == norm || _normalizar(c.apellido) == norm) return c;
      }
      // 2. Coincidencia parcial (nombre completo o solo nombre)
      for (final c in lista) {
        final full = _normalizar('${c.nombre} ${c.apellido}');
        if (full.contains(norm) || norm.contains(_normalizar(c.nombre))) return c;
      }
    } catch (_) {}
    return null;
  }

  String _limpiarError(String e) =>
      e.replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');

  /// Normaliza texto: minúsculas + elimina tildes/acentos para búsqueda robusta.
  String _normalizar(dynamic v) {
    final s = v.toString().toLowerCase().trim();
    const acentos  = 'áéíóúàèìòùäëïöüâêîôûãõñ';
    const normales = 'aeiouaeiouaeiouaeiouaeiouaon';
    final buf = StringBuffer();
    for (final c in s.runes) {
      final ch = String.fromCharCode(c);
      final idx = acentos.indexOf(ch);
      buf.write(idx >= 0 ? normales[idx] : ch);
    }
    return buf.toString();
  }

  /// Convierte de forma segura String o num a int.
  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// Convierte de forma segura String o num a double.
  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}
