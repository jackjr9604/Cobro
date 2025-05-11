import 'package:intl/intl.dart'; // Para formatear fechas

class Cobro {
  final int? id;
  final int clienteId; // ID del cliente asociado
  final String
  clienteNombre; // Nombre del cliente (para mostrar sin hacer join)
  final double monto;
  final DateTime fecha;
  final String ubicacion;
  final String? estado;

  Cobro({
    this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.monto,
    required this.fecha,
    required this.ubicacion,
    this.estado = 'pendiente', // Valor por defecto
  });

  // Constructor para crear un Cobro desde un mapa (usado al leer de la base de datos)
  factory Cobro.fromMap(Map<String, dynamic> map) {
    return Cobro(
      id: map['id'],
      clienteId: map['clienteId'],
      clienteNombre: map['cliente'] ?? 'Cliente desconocido',
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha']),
      ubicacion: map['ubicacion'],
      estado: map['estado'],
    );
  }

  // Convertir Cobro a mapa (para guardar en base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'cliente': clienteNombre,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'ubicacion': ubicacion,
      'estado': estado,
    };
  }

  // Método para crear una copia del cobro con algunos campos modificados
  Cobro copyWith({
    int? id,
    int? clienteId,
    String? clienteNombre,
    double? monto,
    DateTime? fecha,
    String? ubicacion,
    String? estado,
  }) {
    return Cobro(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      ubicacion: ubicacion ?? this.ubicacion,
      estado: estado ?? this.estado,
    );
  }

  // Método para formatear la fecha como string
  String get fechaFormateada {
    return DateFormat('dd/MM/yyyy - HH:mm').format(fecha);
  }

  // Método para formatear el monto como string
  String get montoFormateado {
    return '\$${monto.toStringAsFixed(2)}';
  }

  // Sobreescribir toString para debugging
  @override
  String toString() {
    return 'Cobro{id: $id, clienteId: $clienteId, clienteNombre: $clienteNombre, monto: $monto, fecha: $fecha, ubicacion: $ubicacion, estado: $estado}';
  }

  // Sobreescribir equals y hashCode para comparaciones
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cobro &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          clienteId == other.clienteId &&
          clienteNombre == other.clienteNombre &&
          monto == other.monto &&
          fecha == other.fecha &&
          ubicacion == other.ubicacion &&
          estado == other.estado;

  @override
  int get hashCode =>
      id.hashCode ^
      clienteId.hashCode ^
      clienteNombre.hashCode ^
      monto.hashCode ^
      fecha.hashCode ^
      ubicacion.hashCode ^
      estado.hashCode;
}
