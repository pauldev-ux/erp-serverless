class Cliente {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final String direccion;
  final String rfc;
  final String? fechaRegistro;
  final String? fechaActualizacion;

  Cliente({
    required this.id,
    required this.nombre,
    this.apellido = '',
    required this.email,
    required this.telefono,
    this.direccion = '',
    this.rfc = '',
    this.fechaRegistro,
    this.fechaActualizacion,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] ?? '',
        nombre: json['nombre'] ?? '',
        apellido: json['apellido'] ?? '',
        email: json['email'] ?? '',
        telefono: json['telefono'] ?? '',
        direccion: json['direccion'] ?? '',
        rfc: json['rfc'] ?? '',
        fechaRegistro: json['fechaRegistro'],
        fechaActualizacion: json['fechaActualizacion'],
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'telefono': telefono,
        'direccion': direccion,
        'rfc': rfc,
      };

  String get nombreCompleto => '$nombre $apellido'.trim();
}
