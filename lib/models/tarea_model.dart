import 'dart:convert';

enum EstadoTarea {
  pendiente('Pendiente'),
  enProgreso('En progreso'),
  completada('Completada');

  const EstadoTarea(this.etiqueta);
  final String etiqueta;
}

class Subtarea {
  const Subtarea({required this.titulo, this.completada = false});

  final String titulo;
  final bool completada;

  Map<String, Object> toMap() => {'titulo': titulo, 'completada': completada};

  factory Subtarea.fromMap(Map<String, dynamic> map) => Subtarea(
    titulo: map['titulo'] as String,
    completada: map['completada'] as bool,
  );
}

/// Datos de una tarea, independientes de sus widgets y del acceso a SQLite.
class Tarea {
  Tarea({
    this.id,
    required this.titulo,
    required this.asignatura,
    required this.fechaLimite,
    required this.tipo,
    this.importancia = 3,
    this.estado = EstadoTarea.pendiente,
    List<Subtarea> subtareas = const [],
  }) : subtareas = List.unmodifiable(subtareas) {
    RangeError.checkValueInInterval(importancia, 1, 5, 'importancia');
  }

  final int? id;
  final String titulo;
  final String asignatura;
  final DateTime fechaLimite;
  final String tipo;
  // Entero de 1 (menos importante) a 5 (más importante).
  final int importancia;
  final EstadoTarea estado;
  final List<Subtarea> subtareas;

  int get subtareasCompletadas => subtareas.where((s) => s.completada).length;

  Tarea copyWith({
    int? id,
    String? titulo,
    String? asignatura,
    DateTime? fechaLimite,
    String? tipo,
    int? importancia,
    EstadoTarea? estado,
    List<Subtarea>? subtareas,
  }) => Tarea(
    id: id ?? this.id,
    titulo: titulo ?? this.titulo,
    asignatura: asignatura ?? this.asignatura,
    fechaLimite: fechaLimite ?? this.fechaLimite,
    tipo: tipo ?? this.tipo,
    importancia: importancia ?? this.importancia,
    estado: estado ?? this.estado,
    subtareas: subtareas ?? this.subtareas,
  );

  // SQLite guarda la fecha como un entero y la lista de subtareas como JSON.
  // Así la tarea y sus subtareas se actualizan juntas, en una sola escritura.
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'titulo': titulo,
    'asignatura': asignatura,
    'fecha_limite': fechaLimite.millisecondsSinceEpoch,
    'tipo': tipo,
    'importancia': importancia,
    'estado': estado.name,
    'subtareas': jsonEncode(subtareas.map((s) => s.toMap()).toList()),
  };

  factory Tarea.fromMap(Map<String, Object?> map) => Tarea(
    id: map['id'] as int,
    titulo: map['titulo'] as String,
    asignatura: map['asignatura'] as String,
    fechaLimite: DateTime.fromMillisecondsSinceEpoch(
      map['fecha_limite'] as int,
    ),
    tipo: map['tipo'] as String,
    importancia: map['importancia'] as int,
    estado: EstadoTarea.values.byName(map['estado'] as String),
    subtareas: (jsonDecode(map['subtareas'] as String) as List)
        .map((s) => Subtarea.fromMap(s as Map<String, dynamic>))
        .toList(),
  );

  bool isUrgente() {
    return fechaLimite.difference(DateTime.now()).inDays < 3;
  }

  double getImportanceEmergencyScore(DateTime now) {
    const iFactor = 2.0;
    const eFactor = 1.0;
    final diasRestantes = fechaLimite.difference(now).inHours / 24.0;
    return (importancia * iFactor) /
        ((diasRestantes.clamp(0, double.infinity) + 1) * eFactor);
  }
}
