import 'package:flutter/material.dart';

class Cadran {
  const Cadran({
    required this.titulo,
    required this.descripcion,
    required this.importante,
    required this.urgente,
    required this.color,
  });

  final String titulo;
  final String descripcion;
  final bool importante;
  final bool urgente;
  final Color color;
}
