class Venta {
  final String id;
  final String productoId;
  final String? productoNombre;
  final String? clienteId;
  final String? clienteNombre;
  final int cantidad;
  final double precioUnitario;
  final double total;
  final String estado;
  final String moneda;
  final String? fechaVenta;
  final String? fechaActualizacion;

  Venta({
    required this.id,
    required this.productoId,
    this.productoNombre,
    this.clienteId,
    this.clienteNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    this.estado = 'completada',
    this.moneda = 'Bs',
    this.fechaVenta,
    this.fechaActualizacion,
  });

  factory Venta.fromJson(Map<String, dynamic> json) => Venta(
        id: json['id'] ?? '',
        productoId: json['productoId'] ?? '',
        productoNombre: json['productoNombre'],
        clienteId: json['clienteId'],
        clienteNombre: json['clienteNombre'],
        cantidad: _parse<int>(json['cantidad'], 0),
        precioUnitario: _parse<double>(json['precioUnitario'], 0.0),
        total: _parse<double>(json['total'], 0.0),
        estado: json['estado'] ?? 'completada',
        moneda: json['moneda'] ?? 'Bs',
        fechaVenta: json['fechaVenta'],
        fechaActualizacion: json['fechaActualizacion'],
      );

  static T _parse<T>(dynamic v, T fallback) {
    if (v == null) return fallback;
    if (T == int) {
      if (v is int) return v as T;
      if (v is num) return v.toInt() as T;
      return (int.tryParse(v.toString()) ?? fallback) as T;
    }
    if (T == double) {
      if (v is double) return v as T;
      if (v is num) return v.toDouble() as T;
      return (double.tryParse(v.toString()) ?? fallback) as T;
    }
    return fallback;
  }

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        if (clienteId != null) 'clienteId': clienteId,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'total': total,
        'moneda': moneda,
      };

  String get estadoLabel {
    switch (estado) {
      case 'completada':
        return 'Completada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }
}
