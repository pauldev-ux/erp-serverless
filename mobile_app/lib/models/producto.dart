class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int stock;
  final String categoria;
  final String? fechaCreacion;
  final String? fechaActualizacion;

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    required this.stock,
    this.categoria = 'Sin categoría',
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] ?? '',
        nombre: json['nombre'] ?? '',
        descripcion: json['descripcion'] ?? '',
        precio: _parse<double>(json['precio'], 0.0),
        stock: _parse<int>(json['stock'], 0),
        categoria: json['categoria'] ?? 'Sin categoría',
        fechaCreacion: json['fechaCreacion'],
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
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'stock': stock,
        'categoria': categoria,
      };

  Producto copyWith({
    String? nombre,
    String? descripcion,
    double? precio,
    int? stock,
    String? categoria,
  }) =>
      Producto(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        precio: precio ?? this.precio,
        stock: stock ?? this.stock,
        categoria: categoria ?? this.categoria,
        fechaCreacion: fechaCreacion,
        fechaActualizacion: fechaActualizacion,
      );
}
