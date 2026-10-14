import 'package:flutter/material.dart';

class Asignatura {
  final int? id;
  final String nombre;
  final Color color;

  Asignatura({this.id, required this.nombre, required this.color});

  Map<String, dynamic> toMap(){
    return {'id': id, 'nombre': nombre, 'color': color.toARGB32()};
  }

  factory Asignatura.fromMap(Map<String, dynamic> map){
    return Asignatura(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      color: Color(map['color'] as int),
    );
  }

  Asignatura copyWith({int? id, String? nombre, Color? color}){
    return Asignatura(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
    );
  }
}
