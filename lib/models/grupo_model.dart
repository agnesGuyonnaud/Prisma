// Timestamp para guardar fechas en Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';

// Subtarea y EstadoTarea, compartidos con las tareas personales.
import 'tarea_model.dart';

class Grupo{
  const Grupo({
    required this.codigo,
    required this.nombre,
    required this.integrantes,
    required this.nombres,
  });

  final String codigo;
  final String nombre;
  final List<String> integrantes;
  final Map<String, String> nombres;

  /// Input:
  /// - No recibe parámetros; usa los integrantes y nombres de este grupo.
  /// Output:
  /// - `List<String>`: nombres visibles de los integrantes, en orden.
  /// Resumen:
  /// - Traduce los UID de los integrantes a sus nombres.
  List<String> get nombresIntegrantes => [
    for(final uid in integrantes) nombres[uid] ?? 'Integrante',
  ];

  /// Input:
  /// - No recibe parámetros; usa el nombre, integrantes y nombres del grupo.
  /// Output:
  /// - `Map<String, Object>`: valores serializables para Firestore.
  /// Resumen:
  /// - Convierte el grupo a un mapa; el código se usa como ID del documento.
  Map<String, Object> toMap() => {
    'nombre': nombre,
    'integrantes': integrantes,
    'nombres': nombres,
  };

  /// Input:
  /// - `codigo` (`String`): ID del documento del grupo en Firestore.
  /// - `map` (`Map<String, dynamic>`): datos del documento.
  /// Output:
  /// - `Grupo`: modelo reconstruido.
  /// Resumen:
  /// - Crea un grupo a partir de un documento de Firestore.
  factory Grupo.fromMap(String codigo, Map<String, dynamic> map) => Grupo(
    codigo: codigo,
    nombre: map['nombre'] as String,
    integrantes: List<String>.from(map['integrantes'] as List),
    nombres: Map<String, String>.from(map['nombres'] as Map? ?? {}),
  );
}

class Documento{
  const Documento({
    required this.titulo,
    required this.enlace,
    this.ruta,
    this.tamano,
  });

  final String titulo;
  final String enlace;
  final String? ruta;
  final int? tamano;

  /// Input:
  /// - No recibe parámetros; revisa la ruta de este documento.
  /// Output:
  /// - `bool`: `true` si es un archivo subido y `false` si es un enlace.
  /// Resumen:
  /// - Distingue los archivos guardados en Firestore de los enlaces externos.
  bool get esArchivo => ruta != null;

  /// Input:
  /// - No recibe parámetros; usa el título (nombre del archivo).
  /// Output:
  /// - `String`: extensión en minúsculas, o vacía si es un enlace.
  /// Resumen:
  /// - Obtiene la extensión para elegir el ícono y validar el tipo.
  String get extension{
    final punto = titulo.lastIndexOf('.');
    if(!esArchivo || punto == -1) return '';
    return titulo.substring(punto + 1).toLowerCase();
  }

  /// Input:
  /// - No recibe parámetros; usa los campos de este documento.
  /// Output:
  /// - `Map<String, Object>`: valores serializables, sin los campos nulos.
  /// Resumen:
  /// - Convierte el documento a un mapa para guardarlo en la tarea.
  Map<String, Object> toMap() => {
    'titulo': titulo,
    'enlace': enlace,
    'ruta': ?ruta,
    'tamano': ?tamano,
  };

  /// Input:
  /// - `map` (`Map<String, dynamic>`): datos guardados en la tarea.
  /// Output:
  /// - `Documento`: modelo reconstruido.
  /// Resumen:
  /// - Crea un documento (enlace o archivo) a partir de su mapa.
  factory Documento.fromMap(Map<String, dynamic> map) => Documento(
    titulo: map['titulo'] as String,
    enlace: map['enlace'] as String,
    ruta: map['ruta'] as String?,
    tamano: map['tamano'] as int?,
  );
}

class Nota{
  const Nota({
    required this.autorId,
    required this.autor,
    required this.texto,
    required this.fecha,
  });

  final String autorId;
  final String autor;
  final String texto;
  final DateTime fecha;

  /// Input:
  /// - No recibe parámetros; usa el autor, texto y fecha de esta nota.
  /// Output:
  /// - `Map<String, Object>`: valores serializables para Firestore.
  /// Resumen:
  /// - Convierte la nota a un mapa, con la fecha como `Timestamp`.
  Map<String, Object> toMap() => {
    'autorId': autorId,
    'autor': autor,
    'texto': texto,
    'fecha': Timestamp.fromDate(fecha),
  };

  /// Input:
  /// - `map` (`Map<String, dynamic>`): datos guardados en la tarea.
  /// Output:
  /// - `Nota`: modelo reconstruido.
  /// Resumen:
  /// - Crea una nota a partir de su mapa de Firestore.
  factory Nota.fromMap(Map<String, dynamic> map) => Nota(
    autorId: map['autorId'] as String,
    autor: map['autor'] as String,
    texto: map['texto'] as String,
    fecha: (map['fecha'] as Timestamp).toDate(),
  );
}

class TareaGrupal{
  TareaGrupal({
    this.id,
    required this.grupo,
    required this.titulo,
    required this.asignatura,
    required this.fechaLimite,
    this.estado = EstadoTarea.pendiente,
    List<Subtarea> subtareas = const [],
    List<Documento> documentos = const [],
    List<Nota> notas = const [],
  }) : subtareas = List.unmodifiable(subtareas),
       documentos = List.unmodifiable(documentos),
       notas = List.unmodifiable(notas);

  final String? id;
  final String grupo;
  final String titulo;
  final String asignatura;
  final DateTime fechaLimite;
  final EstadoTarea estado;
  final List<Subtarea> subtareas;
  final List<Documento> documentos;
  final List<Nota> notas;

  /// Input:
  /// - No recibe parámetros; revisa las subtareas de esta tarea.
  /// Output:
  /// - `int`: cantidad de subtareas marcadas como completadas.
  /// Resumen:
  /// - Cuenta las subtareas finalizadas.
  int get subtareasCompletadas => subtareas.where((s) => s.completada).length;

  /// Input:
  /// - No recibe parámetros; usa el grupo y el ID de esta tarea.
  /// Output:
  /// - `String`: identificador único de la tarea entre todos los grupos.
  /// Resumen:
  /// - Genera la clave usada para el evento de Calendar y las listas.
  String get clave => '${grupo}_$id';

  /// Input:
  /// - `id`, `estado` (opcionales): valores que reemplazarán los actuales.
  /// Output:
  /// - `TareaGrupal`: nueva instancia con los campos actualizados.
  /// Resumen:
  /// - Copia la tarea preservando los valores no especificados.
  TareaGrupal copyWith({String? id, EstadoTarea? estado}) => TareaGrupal(
    id: id ?? this.id,
    grupo: grupo,
    titulo: titulo,
    asignatura: asignatura,
    fechaLimite: fechaLimite,
    estado: estado ?? this.estado,
    subtareas: subtareas,
    documentos: documentos,
    notas: notas,
  );

  /// Input:
  /// - No recibe parámetros; usa todos los campos de esta tarea.
  /// Output:
  /// - `Map<String, Object>`: valores serializables para Firestore.
  /// Resumen:
  /// - Convierte la tarea con sus subtareas, documentos y notas a un mapa.
  Map<String, Object> toMap() => {
    'titulo': titulo,
    'asignatura': asignatura,
    'fechaLimite': Timestamp.fromDate(fechaLimite),
    'estado': estado.name,
    'subtareas': [for(final s in subtareas) s.toMap()],
    'documentos': [for(final d in documentos) d.toMap()],
    'notas': [for(final n in notas) n.toMap()],
  };

  /// Input:
  /// - `grupo` (`String`): código del grupo al que pertenece la tarea.
  /// - `id` (`String`): ID del documento de la tarea.
  /// - `map` (`Map<String, dynamic>`): datos del documento.
  /// Output:
  /// - `TareaGrupal`: modelo reconstruido con sus listas anidadas.
  /// Resumen:
  /// - Crea una tarea grupal a partir de un documento de Firestore.
  factory TareaGrupal.fromMap(
    String grupo,
    String id,
    Map<String, dynamic> map,
  ) => TareaGrupal(
    id: id,
    grupo: grupo,
    titulo: map['titulo'] as String,
    asignatura: map['asignatura'] as String,
    fechaLimite: (map['fechaLimite'] as Timestamp).toDate(),
    estado: EstadoTarea.values.byName(map['estado'] as String),
    subtareas: [
      for(final s in map['subtareas'] as List? ?? [])
        Subtarea.fromMap(Map<String, dynamic>.from(s as Map)),
    ],
    documentos: [
      for(final d in map['documentos'] as List? ?? [])
        Documento.fromMap(Map<String, dynamic>.from(d as Map)),
    ],
    notas: [
      for(final n in map['notas'] as List? ?? [])
        Nota.fromMap(Map<String, dynamic>.from(n as Map)),
    ],
  );
}

class ResumenGrupos{
  const ResumenGrupos({required this.grupos, required this.tareas});

  final List<Grupo> grupos;
  final List<TareaGrupal> tareas;

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea cuyo grupo se busca.
  /// Output:
  /// - `Grupo?`: grupo de la tarea o `null` si ya no está en la lista.
  /// Resumen:
  /// - Busca el grupo correspondiente a una tarea por su código.
  Grupo? grupoDe(TareaGrupal tarea){
    for(final grupo in grupos){
      if(grupo.codigo == tarea.grupo) return grupo;
    }
    return null;
  }
}
