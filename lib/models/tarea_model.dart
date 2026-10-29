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

  /// Input:
  /// - No recibe parámetros; usa el título y estado de esta subtarea.
  /// Output:
  /// - `Map<String, Object>`: valores serializables de la subtarea.
  /// Resumen:
  /// - Convierte la subtarea a un mapa para persistencia.
  Map<String, Object> toMap() => {'titulo': titulo, 'completada': completada};

  /// Input:
  /// - `map` (`Map<String, dynamic>`): datos previamente decodificados.
  /// Output:
  /// - `Subtarea`: modelo reconstruido con título y estado.
  /// Resumen:
  /// - Crea una subtarea a partir del mapa persistido.
  factory Subtarea.fromMap(Map<String, dynamic> map) => Subtarea(
    titulo: map['titulo'] as String,
    completada: map['completada'] as bool,
  );
}

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
  }) : subtareas = List.unmodifiable(subtareas){
    RangeError.checkValueInInterval(importancia, 1, 5, 'importancia');
  }

  final int? id;
  final String titulo;
  final String asignatura;
  final DateTime fechaLimite;
  final String tipo;

  final int importancia;
  final EstadoTarea estado;
  final List<Subtarea> subtareas;

  /// Input:
  /// - No recibe parámetros; revisa las subtareas de esta tarea.
  /// Output:
  /// - `int`: cantidad de subtareas marcadas como completadas.
  /// Resumen:
  /// - Cuenta las subtareas finalizadas.
  int get subtareasCompletadas => subtareas.where((s) => s.completada).length;

  /// Input:
  /// - Campos opcionales: valores que reemplazarán los de esta tarea.
  /// Output:
  /// - `Tarea`: nueva instancia con los campos seleccionados actualizados.
  /// Resumen:
  /// - Copia la tarea preservando los valores no especificados.
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

  /// Input:
  /// - No recibe parámetros; usa todos los campos de esta tarea.
  /// Output:
  /// - `Map<String, Object?>`: valores serializables para la base de datos.
  /// Resumen:
  /// - Convierte la tarea y sus subtareas a un mapa persistible.
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

  /// Input:
  /// - `map` (`Map<String, Object?>`): fila de tarea obtenida de la base de datos.
  /// Output:
  /// - `Tarea`: modelo reconstruido, incluidas sus subtareas.
  /// Resumen:
  /// - Decodifica la fila y reconstruye los campos y modelos anidados.
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

  /// Input:
  /// - No recibe parámetros; compara la fecha límite con la hora actual.
  /// Output:
  /// - `bool`: `true` si faltan menos de tres días.
  /// Resumen:
  /// - Clasifica la tarea como urgente según su fecha límite.
  bool isUrgente(){
    return fechaLimite.difference(DateTime.now()).inDays < 3;
  }

  /// Input:
  /// - `now` (`DateTime`): instante de referencia para calcular urgencia.
  /// Output:
  /// - `double`: puntuación que combina importancia y cercanía de la fecha.
  /// Resumen:
  /// - Calcula un puntaje mayor para tareas importantes y próximas a vencer.
  double getImportanceEmergencyScore(DateTime now){
    const iFactor = 2.0;
    const eFactor = 1.0;
    final diasRestantes = fechaLimite.difference(now).inHours / 24.0;
    return (importancia * iFactor) /
        ((diasRestantes.clamp(0, double.infinity) + 1) * eFactor);
  }
}
