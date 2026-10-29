import 'package:flutter/material.dart';

class Asignatura {
  final int? id;
  final String nombre;
  final Color color;

  Asignatura({this.id, required this.nombre, required this.color});

  /// Input:
  /// - No recibe parámetros; usa el ID, nombre y color de esta asignatura.
  /// Output:
  /// - `Map<String, dynamic>`: campos convertidos a valores persistibles.
  /// Resumen:
  /// - Convierte la asignatura a un mapa compatible con la base de datos.
  Map<String, dynamic> toMap(){
    return {'id': id, 'nombre': nombre, 'color': color.toARGB32()};
  }

  /// Input:
  /// - `map` (`Map<String, dynamic>`): fila obtenida de la base de datos.
  /// Output:
  /// - `Asignatura`: modelo reconstruido con su color.
  /// Resumen:
  /// - Convierte los campos almacenados a una instancia de asignatura.
  factory Asignatura.fromMap(Map<String, dynamic> map){
    return Asignatura(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      color: Color(map['color'] as int),
    );
  }

  /// Input:
  /// - `id`, `nombre`, `color` (opcionales): valores que reemplazarán los actuales.
  /// Output:
  /// - `Asignatura`: nueva instancia con los campos seleccionados actualizados.
  /// Resumen:
  /// - Copia la asignatura preservando los valores no especificados.
  Asignatura copyWith({int? id, String? nombre, Color? color}){
    return Asignatura(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
    );
  }
}
