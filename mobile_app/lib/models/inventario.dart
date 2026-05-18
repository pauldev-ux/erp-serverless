class Inventario {
  final String productoId;
  final String? nombreProducto;
  final int cantidadActual;
  final String? fechaActualizacion;

  Inventario({
    required this.productoId,
    this.nombreProducto,
    required this.cantidadActual,
    this.fechaActualizacion,
  });

  factory Inventario.fromJson(Map<String, dynamic> json) => Inventario(
        productoId: json['productoId'] ?? json['producto_id'] ?? '',
        nombreProducto: json['nombreProducto'] ?? json['nombre'],
        cantidadActual: _parseInt(json['cantidadActual'] ?? json['cantidad']),
        fechaActualizacion: json['fechaActualizacion'] ?? json['updated_at'],
      );

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'cantidadActual': cantidadActual,
      };

  /// Color semáforo según nivel de stock
  StockNivel get nivel {
    if (cantidadActual <= 5) return StockNivel.critico;
    if (cantidadActual <= 20) return StockNivel.bajo;
    return StockNivel.ok;
  }
}

class MovimientoInventario {
  final String? id;
  final String productoId;
  final String tipo; // 'entrada' | 'salida'
  final int cantidad;
  final String? fecha;

  MovimientoInventario({
    this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    this.fecha,
  });

  factory MovimientoInventario.fromJson(Map<String, dynamic> json) =>
      MovimientoInventario(
        id: json['id'],
        productoId: json['productoId'] ?? json['producto_id'] ?? '',
        tipo: json['tipo'] ?? 'entrada',
        cantidad: _parseInt(json['cantidad']),
        fecha: json['fecha'] ?? json['created_at'],
      );

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
      };
}

enum StockNivel { ok, bajo, critico }
