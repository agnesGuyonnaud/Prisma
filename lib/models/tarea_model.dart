import 'dart:convert';

enum ImportanciaTarea {
  baja('Baja'),
  media('Media'),
  alta('Alta');

  const ImportanciaTarea(this.etiqueta);
  final String etiqueta;
}

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
    this.importancia = ImportanciaTarea.media,
    this.estado = EstadoTarea.pendiente,
    List<Subtarea> subtareas = const [],
  }) : subtareas = List.unmodifiable(subtareas);

  final int? id;
  final String titulo;
  final String asignatura;
  final DateTime fechaLimite;
  final String tipo;
  final ImportanciaTarea importancia;
  final EstadoTarea estado;
  final List<Subtarea> subtareas;

  int get subtareasCompletadas => subtareas.where((s) => s.completada).length;

  Tarea copyWith({
    int? id,
    String? titulo,
    String? asignatura,
    DateTime? fechaLimite,
    String? tipo,
    ImportanciaTarea? importancia,
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
    'importancia': importancia.name,
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
    importancia: ImportanciaTarea.values.byName(map['importancia'] as String),
    estado: EstadoTarea.values.byName(map['estado'] as String),
    subtareas: (jsonDecode(map['subtareas'] as String) as List)
        .map((s) => Subtarea.fromMap(s as Map<String, dynamic>))
        .toList(),
  );
}
