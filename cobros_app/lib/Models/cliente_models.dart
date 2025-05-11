class Cliente {
  final int? id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;
  final DateTime fechaRegistro;

  Cliente({
    this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.direccion,
    DateTime? fechaRegistro,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  Cliente copyWith({
    int? id,
    String? nombre,
    String? telefono,
    String? email,
    String? direccion,
    DateTime? fechaRegistro,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
      telefono: map['telefono'],
      email: map['email'],
      direccion: map['direccion'],
      fechaRegistro: DateTime.parse(map['fechaRegistro']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'fechaRegistro': fechaRegistro.toIso8601String(),
    };
  }
}
