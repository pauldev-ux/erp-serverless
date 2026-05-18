class Compra {
  final String id;
  final String productoId;
  final String? productoNombre;
  final int cantidad;
  final double precioUnitario;
  final double total;
  final String estado;
  final String moneda;
  final String? proveedor;
  final String? fechaCompra;
  final String? fechaActualizacion;

  Compra({
    required this.id,
    required this.productoId,
    this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    this.estado = 'pendiente',
    this.moneda = 'Bs',
    this.proveedor,
    this.fechaCompra,
    this.fechaActualizacion,
  });

  factory Compra.fromJson(Map<String, dynamic> json) => Compra(
        id: json['id'] ?? '',
        productoId: json['productoId'] ?? '',
        productoNombre: json['productoNombre'],
        cantidad: _parse<int>(json['cantidad'], 0),
        precioUnitario: _parse<double>(json['precioUnitario'], 0.0),
        total: _parse<double>(json['total'], 0.0),
        estado: json['estado'] ?? 'pendiente',
        moneda: json['moneda'] ?? 'Bs',
        proveedor: json['proveedor'],
        fechaCompra: json['fechaCompra'],
        fechaActualizacion: json['fechaActualizacion'],
      );

  /// Parsea un valor que puede ser String o num de forma segura.
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
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'total': total,
        'moneda': moneda,
        if (proveedor != null) 'proveedor': proveedor,
      };

  String get estadoLabel {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'recibido':
        return 'Recibido';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }
}
