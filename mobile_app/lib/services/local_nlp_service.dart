import 'dart:convert';

/// Parser de lenguaje natural 100% local (Dart puro).
/// No requiere servidor externo. Corre directamente en el dispositivo móvil.
///
/// Soporta:
///   - Múltiples intenciones separadas por "y"
///   - cliente: crear, listar, eliminar
///   - producto: crear, listar, actualizar_precio, eliminar
///   - inventario: actualizar_stock, consultar_stock, listar_movimientos
///   - compra: registrar, listar, recibir
///   - venta: registrar, listar, cancelar
class LocalNlpService {
  // ── Normalización ─────────────────────────────────────────────────────────────
  static String _norm(String s) {
    const ac = 'áéíóúàèìòùäëïöüâêîôûãõñÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÃÕÑ';
    const nm = 'aeiouaeiouaeiouaeiouaeiouaonAEIOUAEIOUAEIOUAEIOUAEIOUAON';
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final idx = ac.indexOf(ch);
      buf.write(idx >= 0 ? nm[idx] : ch);
    }
    return buf.toString().toLowerCase().trim();
  }

  // ── Extracción de número ──────────────────────────────────────────────────────
  static double? _num(String s) => double.tryParse(
      RegExp(r'\d+\.?\d*').firstMatch(s)?.group(0) ?? '');

  // ── Punto de entrada principal ────────────────────────────────────────────────

  /// Parsea [texto] en lenguaje natural y retorna una lista de Tool Actions
  /// estructurados como `[{"tool":..., "action":..., "payload":{...}}]`.
  /// Si no se reconoce ninguna intención, retorna lista vacía.
  List<Map<String, dynamic>> parsear(String texto) {
    // Dividir por conjunciones para multi-intent
    final segmentos = _dividirSegmentos(texto);
    final acciones = <Map<String, dynamic>>[];

    for (final seg in segmentos) {
      final accion = _parsearSegmento(seg.trim());
      if (accion != null) acciones.add(accion);
    }

    // ── Vinculación de contexto: cliente → venta/compra ─────────────────────
    // Si hay una acción "cliente crear" Y una "venta registrar" sin clienteNombre,
    // automáticamente vincula el nombre del cliente recién creado a la venta.
    _vincularClienteAVenta(acciones);

    return acciones;
  }

  /// Vincula automáticamente el cliente de una acción "cliente.crear"
  /// a las acciones "venta.registrar" que no tengan clienteNombre.
  void _vincularClienteAVenta(List<Map<String, dynamic>> acciones) {
    // Buscar si hay una acción de crear cliente
    Map<String, dynamic>? accionCliente;
    for (final a in acciones) {
      if (a['tool'] == 'cliente' && a['action'] == 'crear') {
        accionCliente = a;
        break;
      }
    }
    if (accionCliente == null) return;

    final nombreCliente = accionCliente['payload']?['nombre'] ?? '';
    final apellidoCliente = accionCliente['payload']?['apellido'] ?? '';
    final nombreCompleto = '$nombreCliente $apellidoCliente'.trim();
    if (nombreCompleto.isEmpty) return;

    // Vincular el nombre a ventas y compras sin cliente especificado
    for (final a in acciones) {
      final payload = a['payload'] as Map<String, dynamic>? ?? {};
      if (a['tool'] == 'venta' && a['action'] == 'registrar') {
        if ((payload['clienteNombre'] ?? '').toString().isEmpty &&
            (payload['cliente_id'] ?? '').toString().isEmpty) {
          payload['clienteNombre'] = nombreCompleto;
          a['payload'] = payload;
        }
      }
    }
  }

  /// Convierte la lista de acciones a JSON string (compatible con IaMessage).
  String parsearAJson(String texto) {
    final acciones = parsear(texto);
    if (acciones.isEmpty) return '[]';
    return jsonEncode(acciones);
  }


  // ── División en segmentos ─────────────────────────────────────────────────────
  List<String> _dividirSegmentos(String texto) {
    // Separar por " y " pero NO separar dentro de "actualizar precio ... a ..."
    final partes = texto.split(RegExp(r'\s+y\s+', caseSensitive: false));
    // Reagrupar segmentos que comiencen con "a " (precio a X → son continuación)
    final resultado = <String>[];
    for (var i = 0; i < partes.length; i++) {
      final p = partes[i];
      if (resultado.isNotEmpty &&
          RegExp(r'^(a\s+\d|bolivianos|bs)', caseSensitive: false)
              .hasMatch(p.trimLeft())) {
        resultado[resultado.length - 1] += ' y $p';
      } else {
        resultado.add(p);
      }
    }
    return resultado.isEmpty ? [texto] : resultado;
  }

  // ── Parser por segmento (ES + EN) ───────────────────────────────────────────
  Map<String, dynamic>? _parsearSegmento(String seg) {
    final n = _norm(seg);

    // ── CLIENTE / CLIENT ───────────────────────────────────────────────────────
    if (_contieneAlguna(n, [
      'registrar cliente', 'crear cliente', 'nuevo cliente', 'agregar cliente',
      'register client', 'create client', 'add client', 'new client', 'register customer', 'create customer', 'add customer',
    ])) return _parsearCrearCliente(seg);

    if (_contieneAlguna(n, [
      'listar cliente', 'lista cliente', 'ver cliente', 'mostrar cliente', 'todos los clientes',
      'list client', 'show client', 'get client', 'list customer', 'show customer', 'all clients',
    ])) return _accion('cliente', 'listar', {});

    if (_contieneAlguna(n, [
      'eliminar cliente', 'borrar cliente',
      'delete client', 'remove client', 'delete customer',
    ])) {
      final id = _extraerParam(seg, ['id', 'ID']);
      return _accion('cliente', 'eliminar', {'id': id ?? ''});
    }

    // ── PRODUCTO / PRODUCT ─────────────────────────────────────────────────────
    if (_contieneAlguna(n, [
      'crear producto', 'registrar producto', 'nuevo producto', 'agregar producto',
      'create product', 'register product', 'add product', 'new product',
    ])) return _parsearCrearProducto(seg);

    if (_contieneAlguna(n, [
      'listar producto', 'lista producto', 'ver producto', 'mostrar producto',
      'todos los producto', 'listar todos', 'ver todos los producto',
      'list product', 'show product', 'get product', 'all product',
    ])) return _accion('producto', 'listar', {});

    if (_contieneAlguna(n, [
      'actualizar precio', 'cambiar precio', 'modificar precio', 'nuevo precio', 'precio de',
      'update price', 'change price', 'set price', 'price of',
    ])) return _parsearActualizarPrecio(seg);

    if (_contieneAlguna(n, [
      'eliminar producto', 'borrar producto',
      'delete product', 'remove product',
    ])) {
      final id = _extraerParam(seg, ['id', 'ID']);
      return _accion('producto', 'eliminar', {'id': id ?? ''});
    }

    // ── INVENTARIO / INVENTORY ─────────────────────────────────────────────────
    if (_contieneAlguna(n, [
      'actualizar stock', 'modificar stock', 'cambiar stock', 'ajustar stock',
      'update stock', 'set stock', 'update inventory', 'set inventory', 'stock for',
    ])) return _parsearActualizarStock(seg);

    if (_contieneAlguna(n, [
      'consultar stock', 'ver stock', 'revisar stock', 'stock actual',
      'stock de', 'stock del', 'cuanto hay de',
      'check stock', 'get stock', 'stock check', 'query stock', 'inventory of',
    ])) return _parsearConsultarStock(seg);

    if (_contieneAlguna(n, [
      'listar movimiento', 'ver movimiento', 'historial',
      'list movement', 'movement history', 'inventory history',
    ])) return _accion('inventario', 'listar_movimientos', {});

    // ── COMPRA / PURCHASE ─────────────────────────────────────────────────────
    // IMPORTANTE: "purchase" va ANTES de "sale/sell" para evitar falsos positivos
    if (_contieneAlguna(n, [
      'registrar compra', 'nueva compra', 'hacer compra', 'compra de', 'comprar',
      'create purchase', 'register purchase', 'make purchase', 'purchase for',
      'purchase of', 'buy product', 'order product',
    ])) return _parsearRegistrarCompra(seg);

    if (_contieneAlguna(n, [
      'listar compra', 'ver compra', 'mostrar compra', 'todas las compra',
      'list purchase', 'show purchase', 'get purchase', 'all purchase',
    ])) return _accion('compra', 'listar', {});

    if (_contieneAlguna(n, [
      'recibir compra', 'recibir pedido', 'marcar recibida',
      'receive purchase', 'receive order', 'mark received',
    ])) {
      final id = _extraerParam(seg, ['id', 'ID']);
      return _accion('compra', 'recibir', {'id': id ?? ''});
    }

    // ── VENTA / SALE ───────────────────────────────────────────────────────────
    if (_contieneAlguna(n, [
      'registrar venta', 'nueva venta', 'hacer venta', 'venta de', 'vender',
      'create sale', 'register sale', 'make sale', 'sell product',
      'sale for', 'sale of', 'create a sale', 'register a sale',
    ])) return _parsearRegistrarVenta(seg);

    if (_contieneAlguna(n, [
      'listar venta', 'ver venta', 'mostrar venta', 'todas las venta',
      'list sale', 'show sale', 'get sale', 'all sale',
    ])) return _accion('venta', 'listar', {});

    if (_contieneAlguna(n, [
      'cancelar venta', 'anular venta',
      'cancel sale', 'void sale',
    ])) {
      final id = _extraerParam(seg, ['id', 'ID']);
      return _accion('venta', 'cancelar', {'id': id ?? ''});
    }

    return null; // No reconocido
  }

  // ── Parsers específicos ───────────────────────────────────────────────────────

  Map<String, dynamic> _parsearCrearCliente(String seg) {
    final stopWords = {
      'registrar', 'crear', 'nuevo', 'agregar', 'añadir', 'cliente',
      'register', 'create', 'add', 'new', 'client', 'customer',
      'nombre', 'apellido', 'email', 'telefono', 'tel', 'name', 'lastname', 'phone',
    };

    // Extraer email si está presente
    final emailMatch = RegExp(r'[\w.+-]+@[\w-]+\.\w+').firstMatch(seg);
    final email = emailMatch?.group(0);

    // Extraer teléfono (secuencia de 7+ dígitos)
    final telMatch = RegExp(r'\b\d{7,}\b').firstMatch(seg);
    final telefono = telMatch?.group(0);

    // Limpiar el texto de palabras clave, email y teléfono para extraer nombre
    String limpio = seg;
    if (email != null) limpio = limpio.replaceAll(email, '');
    if (telefono != null) limpio = limpio.replaceAll(telefono, '');

    final palabras = limpio
        .split(RegExp(r'[\s,]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !stopWords.contains(_norm(w)))
        .toList();

    final nombre = palabras.isNotEmpty ? palabras[0] : '';
    final apellido = palabras.length > 1 ? palabras[1] : '';

    return _accion('cliente', 'crear', {
      'nombre': nombre,
      'apellido': apellido,
      if (email != null) 'email': email,
      if (telefono != null) 'telefono': telefono,
    });
  }

  Map<String, dynamic> _parsearCrearProducto(String seg) {
    final n = _norm(seg);
    final stopWords = {
      'crear', 'registrar', 'nuevo', 'agregar', 'añadir', 'producto',
      'precio', 'stock', 'categoria', 'bs', 'bolivianos',
    };

    final precio = _extraerNumeroTras(n, ['precio', 'bs', 'bolivianos', 'a']);
    final stock = _extraerNumeroTras(n, ['stock', 'cantidad', 'unidades', 'existencia']);

    String limpio = seg;
    final palabras = limpio
        .split(RegExp(r'[\s,]+'))
        .map((w) => w.trim())
        .where((w) {
          if (w.isEmpty) return false;
          if (stopWords.contains(_norm(w))) return false;
          if (RegExp(r'^\d').hasMatch(w)) return false;
          return true;
        })
        .toList();

    final nombre = palabras.isNotEmpty ? palabras[0] : '';

    return _accion('producto', 'crear', {
      'nombre': nombre,
      if (precio != null) 'precio': precio,
      if (stock != null) 'stock': stock.toInt(),
    });
  }

  Map<String, dynamic> _parsearActualizarPrecio(String seg) {
    final n = _norm(seg);
    final precio = _extraerNumeroTras(n, ['a', 'precio', 'bs', 'bolivianos']);
    // IMPORTANTE: poner 'del'/'precio del' ANTES de 'de'/'precio de'
    // para evitar que 'de' capture 'del' y deje 'l' sobrante
    final prod = _extraerProductoEntre(n,
        ['precio del', 'precio de', 'del', 'de'],
        ['a ', 'bs', 'bolivianos']);
    return _accion('producto', 'actualizar_precio', {
      'producto': prod ?? '',
      if (precio != null) 'precio': precio,
    });
  }

  Map<String, dynamic> _parsearActualizarStock(String seg) {
    final n = _norm(seg);
    final cantidad = _extraerNumeroTras(n, ['a', 'cantidad', 'stock', 'unidades', 'existencia']) ??
        _extraerPrimerNumero(n);
    // IMPORTANTE: 'stock del'/'stock de' antes de 'del'/'de'
    final prod = _extraerProductoEntre(n,
        ['stock del', 'stock de', 'existencia del', 'existencia de',
         'actualizar el', 'actualizar', 'cantidad del', 'cantidad de', 'del', 'de'],
        ['a ', 'cantidad', 'unidades', RegExp(r'\d').pattern]);
    return _accion('inventario', 'actualizar_stock', {
      'producto': prod ?? '',
      if (cantidad != null) 'cantidad': cantidad.toInt(),
    });
  }

  Map<String, dynamic> _parsearConsultarStock(String seg) {
    final n = _norm(seg);
    // IMPORTANTE: 'stock del' antes de 'stock de', y 'del' antes de 'de'
    final prod = _extraerProductoEntre(n,
        ['stock del', 'stock de', 'disponible del', 'disponible de',
         'hay del', 'hay de', 'cuanto', 'consultar', 'del', 'de'],
        ['a ', 'cantidad', 'unidades']);
    return _accion('inventario', 'consultar_stock', {'producto': prod ?? ''});
  }

  Map<String, dynamic> _parsearRegistrarCompra(String seg) {
    final n = _norm(seg);

    final cantidad = _extraerNumeroTras(n, ['cantidad', 'quantity', 'units', 'unidades', 'kg', 'litros']) ??
        _extraerPrimerNumeroLuegoDe(n, 'de') ?? 1;
    final precio = _extraerNumeroTras(n, ['precio', 'price', 'bs', 'bolivianos', 'usd', 'a', 'costo', 'cost']);
    // Proveedor: ES y EN
    final proveedor = _extraerPalabraluegoDe(seg, [
      'proveedor', 'supplier', 'vendor', 'de parte de', 'provided by', 'from',
    ]);
    final prod = _extraerProductoEntre(n,
        ['purchase for product', 'purchase of', 'compra de', 'comprar', 'buy', 'order', 'de'],
        ['proveedor', 'supplier', 'vendor', 'cantidad', 'quantity', 'precio', 'price', 'bs', 'usd', r'\d',
         'customer', 'client', 'cliente']);
    // Moneda: detectar USD / bolivianos / Bs
    final moneda = n.contains('usd') ? 'USD'
        : n.contains('dollar') ? 'USD'
        : 'Bs';
    // Cliente por nombre: "Customer Juan" / "cliente Juan"
    final clienteNombre = _extraerPalabraluegoDe(seg, [
      'customer', 'client', 'cliente', 'para el cliente', 'for customer', 'for client',
    ]);

    return _accion('compra', 'registrar', {
      'producto': prod ?? '',
      'cantidad': (cantidad is double) ? cantidad.toInt() : cantidad,
      if (precio != null) 'precio': precio,
      if (proveedor != null) 'proveedor': proveedor,
      if (clienteNombre != null) 'clienteNombre': clienteNombre,
      'moneda': moneda,
    });
  }

  Map<String, dynamic> _parsearRegistrarVenta(String seg) {
    final n = _norm(seg);

    final cantidad = _extraerNumeroTras(n, ['cantidad', 'quantity', 'units', 'unidades', 'de']) ??
        _extraerPrimerNumeroLuegoDe(n, 'venta de') ??
        _extraerPrimerNumeroLuegoDe(n, 'sale of') ?? 1;
    final precio = _extraerNumeroTras(n, ['precio', 'price', 'bs', 'bolivianos', 'usd', 'a', 'valor', 'value']);
    final prod = _extraerProductoEntre(n,
        ['sale for product', 'venta de', 'vender', 'sell', 'de'],
        ['cantidad', 'quantity', 'precio', 'price', 'bs', 'usd', 'unidades', 'units', r'\d',
         'customer', 'client', 'cliente']);
    // Cliente por nombre: "Customer Juan" / "cliente Juan"
    final clienteNombre = _extraerPalabraluegoDe(seg, ['customer', 'client', 'cliente', 'para el cliente', 'for customer']);
    // Moneda
    final moneda = n.contains('usd') ? 'USD'
        : n.contains('dollar') ? 'USD'
        : 'Bs';

    return _accion('venta', 'registrar', {
      'producto': prod ?? '',
      'cantidad': (cantidad is double) ? cantidad.toInt() : cantidad,
      if (precio != null) 'precio': precio,
      if (clienteNombre != null) 'clienteNombre': clienteNombre,
      'moneda': moneda,
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> _accion(String tool, String action, Map<String, dynamic> payload) =>
      {'tool': tool, 'action': action, 'payload': payload};

  bool _contieneAlguna(String texto, List<String> keywords) =>
      keywords.any((k) => texto.contains(k));

  String? _extraerParam(String seg, List<String> claves) {
    for (final clave in claves) {
      final m = RegExp('$clave\\s*[=:]?\\s*(\\S+)', caseSensitive: false).firstMatch(seg);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Extrae el primer número que aparece DESPUÉS de alguna de las palabras clave.
  double? _extraerNumeroTras(String texto, List<String> claves) {
    for (final clave in claves) {
      final pattern = RegExp('${RegExp.escape(clave)}\\s+(\\d+\\.?\\d*)');
      final m = pattern.firstMatch(texto);
      if (m != null) return double.tryParse(m.group(1)!);
    }
    return null;
  }

  /// Extrae el primer número del texto.
  double? _extraerPrimerNumero(String texto) {
    final m = RegExp(r'\d+\.?\d*').firstMatch(texto);
    return m != null ? double.tryParse(m.group(0)!) : null;
  }

  /// Extrae el primer número después de una frase específica.
  double? _extraerPrimerNumeroLuegoDe(String texto, String luegoDe) {
    final idx = texto.indexOf(luegoDe);
    if (idx < 0) return null;
    final sub = texto.substring(idx + luegoDe.length);
    return _extraerPrimerNumero(sub);
  }

  /// Extrae la primera palabra después de una de las claves.
  String? _extraerPalabraluegoDe(String seg, List<String> claves) {
    for (final clave in claves) {
      final m = RegExp('${RegExp.escape(clave)}\\s+(\\S+)', caseSensitive: false).firstMatch(seg);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Extrae una palabra/frase entre palabras clave de inicio y fin.
  String? _extraerProductoEntre(String texto, List<String> inicios, List<String> fins) {
    for (final ini in inicios) {
      final idx = texto.indexOf(ini);
      if (idx < 0) continue;
      final sub = texto.substring(idx + ini.length).trim();

      // Encuentra dónde termina el nombre del producto
      int finIdx = sub.length;
      for (final fin in fins) {
        final f = sub.indexOf(fin);
        if (f > 0 && f < finIdx) finIdx = f;
      }

      final extracto = sub.substring(0, finIdx).trim();
      // Tomar solo la primera "palabra significativa" (puede ser compuesta)
      final palabras = extracto
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && !RegExp(r'^\d').hasMatch(w))
          .take(2)
          .toList();
      if (palabras.isNotEmpty) return palabras.join(' ');
    }
    return null;
  }
}
