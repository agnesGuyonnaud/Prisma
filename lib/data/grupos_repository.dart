// StreamController y StreamSubscription para combinar grupos y tareas.
import 'dart:async';
// Random.secure para generar códigos de grupo y min para cortar archivos.
import 'dart:math';
// Uint8List y BytesBuilder para manejar los bytes de los archivos.
import 'dart:typed_data';

// Firestore: base de datos compartida entre los integrantes.
import 'package:cloud_firestore/cloud_firestore.dart';
// Usuario con sesión iniciada (UID y nombre).
import 'package:firebase_auth/firebase_auth.dart';

// Modelos Grupo, TareaGrupal, Documento, Nota y ResumenGrupos.
import '../models/grupo_model.dart';
// Subtarea y EstadoTarea.
import '../models/tarea_model.dart';

class GruposRepository{
  GruposRepository({this.firestore, this.auth});

  static final GruposRepository instancia = GruposRepository();
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  static const tamanoMaximo = 5 * 1024 * 1024;
  static const _tamanoParte = 700 * 1024;
  static const extensionesArchivo = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'txt',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'zip',
  ];

  /// Input:
  /// - No recibe parámetros; usa la instancia inyectada o la global.
  /// Output:
  /// - `FirebaseFirestore`: conexión a Firestore.
  /// Resumen:
  /// - Centraliza la instancia de Firestore usada por el repositorio.
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  /// Input:
  /// - No recibe parámetros.
  /// Output:
  /// - `CollectionReference`: colección `grupos`.
  /// Resumen:
  /// - Devuelve la referencia a la colección de grupos.
  CollectionReference<Map<String, dynamic>> get _grupos =>
      _db.collection('grupos');

  /// Input:
  /// - `grupo` (`String`): código del grupo.
  /// Output:
  /// - `CollectionReference`: subcolección `tareas` del grupo.
  /// Resumen:
  /// - Devuelve la referencia a las tareas de un grupo.
  CollectionReference<Map<String, dynamic>> _tareas(String grupo) =>
      _grupos.doc(grupo).collection('tareas');

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña de los archivos.
  /// Output:
  /// - `CollectionReference`: subcolección `archivos` de la tarea.
  /// Resumen:
  /// - Devuelve la referencia donde se guardan los archivos de una tarea.
  CollectionReference<Map<String, dynamic>> _archivos(TareaGrupal tarea) =>
      _tareas(tarea.grupo).doc(tarea.id).collection('archivos');

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña del archivo.
  /// - `archivo` (`String`): ID del archivo.
  /// Output:
  /// - `CollectionReference`: subcolección `partes` del archivo.
  /// Resumen:
  /// - Devuelve la referencia a los trozos en que se divide un archivo.
  CollectionReference<Map<String, dynamic>> _partes(
    TareaGrupal tarea,
    String archivo,
  ) => _archivos(tarea).doc(archivo).collection('partes');

  /// Input:
  /// - No recibe parámetros; consulta la sesión de Firebase Auth.
  /// Output:
  /// - `User`: usuario con sesión iniciada.
  /// Resumen:
  /// - Obtiene el usuario actual o lanza un error si no hay sesión.
  User get _usuario{
    final usuario = (auth ?? FirebaseAuth.instance).currentUser;
    if(usuario == null){
      throw StateError('Debes iniciar sesión para usar los grupos.');
    }
    return usuario;
  }

  /// Input:
  /// - No recibe parámetros; usa el usuario actual.
  /// Output:
  /// - `String`: UID del usuario con sesión iniciada.
  /// Resumen:
  /// - Expone el identificador del usuario actual.
  String get uid => _usuario.uid;

  /// Input:
  /// - No recibe parámetros; usa el usuario actual.
  /// Output:
  /// - `String`: nombre visible, correo o `"Integrante"`.
  /// Resumen:
  /// - Obtiene el nombre que verán los demás integrantes.
  String get _nombreUsuario{
    final nombre = _usuario.displayName?.trim() ?? '';
    if(nombre.isNotEmpty) return nombre;
    return _usuario.email ?? 'Integrante';
  }

  /// Input:
  /// - No recibe parámetros; usa el UID del usuario actual.
  /// Output:
  /// - `Stream<List<Grupo>>`: grupos del usuario, ordenados por nombre.
  /// Resumen:
  /// - Escucha en tiempo real los grupos a los que pertenece el usuario.
  Stream<List<Grupo>> grupos(){
    return _grupos
        .where('integrantes', arrayContains: uid)
        .snapshots()
        .map((consulta){
          final lista = [
            for(final doc in consulta.docs) Grupo.fromMap(doc.id, doc.data()),
          ];
          lista.sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );
          return lista;
        });
  }

  /// Input:
  /// - `grupo` (`String`): código del grupo.
  /// Output:
  /// - `Stream<List<TareaGrupal>>`: tareas del grupo.
  /// Resumen:
  /// - Escucha en tiempo real las tareas de un grupo.
  Stream<List<TareaGrupal>> tareas(String grupo){
    return _tareas(grupo).snapshots().map(
      (consulta) => [
        for(final doc in consulta.docs)
          TareaGrupal.fromMap(grupo, doc.id, doc.data()),
      ],
    );
  }

  /// Input:
  /// - `grupo` (`String`): código del grupo.
  /// - `id` (`String`): ID de la tarea.
  /// Output:
  /// - `Stream<TareaGrupal?>`: tarea actualizada o `null` si fue eliminada.
  /// Resumen:
  /// - Escucha en tiempo real los cambios de una tarea.
  Stream<TareaGrupal?> tarea(String grupo, String id){
    return _tareas(grupo).doc(id).snapshots().map((doc){
      final datos = doc.data();
      return datos == null ? null : TareaGrupal.fromMap(grupo, doc.id, datos);
    });
  }

  /// Input:
  /// - No recibe parámetros; usa los grupos del usuario actual.
  /// Output:
  /// - `Stream<ResumenGrupos>`: grupos y todas sus tareas, por fecha límite.
  /// Resumen:
  /// - Combina los grupos con las tareas de cada uno, escuchando los grupos
  ///   nuevos y dejando de escuchar los que el usuario abandona.
  Stream<ResumenGrupos> resumen(){
    late final StreamController<ResumenGrupos> controlador;
    StreamSubscription<List<Grupo>>? suscripcionGrupos;
    final suscripcionesTareas = <String, StreamSubscription<List<TareaGrupal>>>{};
    final tareasPorGrupo = <String, List<TareaGrupal>>{};
    var actuales = <Grupo>[];

    /// Input:
    /// - No recibe parámetros; usa los grupos y tareas cargados.
    /// Output:
    /// - `void`: agrega un resumen al stream.
    /// Resumen:
    /// - Emite el resumen solo cuando todos los grupos tienen sus tareas.
    void emitir(){
      if(actuales.any((g) => !tareasPorGrupo.containsKey(g.codigo))) return;
      final todas = [for(final lista in tareasPorGrupo.values) ...lista];
      todas.sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
      controlador.add(ResumenGrupos(grupos: actuales, tareas: todas));
    }

    controlador = StreamController<ResumenGrupos>(
      onListen: (){
        suscripcionGrupos = grupos().listen((lista){
          actuales = lista;
          final codigos = {for(final g in lista) g.codigo};
          for(final codigo in suscripcionesTareas.keys.toList()){
            if(!codigos.contains(codigo)){
              suscripcionesTareas.remove(codigo)!.cancel();
              tareasPorGrupo.remove(codigo);
            }
          }
          for(final codigo in codigos){
            suscripcionesTareas[codigo] ??= tareas(codigo).listen(
              (tareasGrupo){
                tareasPorGrupo[codigo] = tareasGrupo;
                emitir();
              },
              onError: (Object error){
                if(suscripcionesTareas.containsKey(codigo)){
                  controlador.addError(error);
                }
              },
            );
          }
          emitir();
        }, onError: controlador.addError);
      },
      onCancel: () async{
        await suscripcionGrupos?.cancel();
        for(final suscripcion in suscripcionesTareas.values){
          await suscripcion.cancel();
        }
      },
    );
    return controlador.stream;
  }

  /// Input:
  /// - `nombre` (`String`): nombre del grupo nuevo.
  /// Output:
  /// - `Future<Grupo>`: grupo creado, con su código.
  /// Resumen:
  /// - Genera un código libre y crea el grupo con el usuario como integrante.
  Future<Grupo> crearGrupo(String nombre) async{
    if(nombre.trim().isEmpty){
      throw ArgumentError('Debes escribir un nombre para el grupo.');
    }
    var codigo = _generarCodigo();
    while((await _grupos.doc(codigo).get()).exists){
      codigo = _generarCodigo();
    }
    final grupo = Grupo(
      codigo: codigo,
      nombre: nombre.trim(),
      integrantes: [uid],
      nombres: {uid: _nombreUsuario},
    );
    await _grupos.doc(codigo).set(grupo.toMap());
    return grupo;
  }

  /// Input:
  /// - No recibe parámetros.
  /// Output:
  /// - `String`: código aleatorio de 6 caracteres.
  /// Resumen:
  /// - Genera un código sin caracteres confusos (sin O, 0, I ni 1).
  String _generarCodigo(){
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final azar = Random.secure();
    return String.fromCharCodes([
      for(var i = 0; i < 6; i++) letras.codeUnitAt(azar.nextInt(letras.length)),
    ]);
  }

  /// Input:
  /// - `codigo` (`String`): código del grupo escrito por el usuario.
  /// Output:
  /// - `Future<Grupo>`: grupo al que se unió.
  /// Resumen:
  /// - Valida el código y agrega al usuario a los integrantes del grupo.
  Future<Grupo> unirseAGrupo(String codigo) async{
    final limpio = codigo.trim().toUpperCase();
    if(!RegExp(r'^[A-Z0-9]{6}$').hasMatch(limpio)){
      throw ArgumentError('El código tiene 6 letras o números.');
    }
    final referencia = _grupos.doc(limpio);
    final documento = await referencia.get();
    final datos = documento.data();
    if(datos == null){
      throw ArgumentError('No existe un grupo con ese código.');
    }
    await referencia.update({
      'integrantes': FieldValue.arrayUnion([uid]),
      'nombres.$uid': _nombreUsuario,
    });
    return Grupo.fromMap(limpio, datos);
  }

  /// Input:
  /// - `grupo` (`Grupo`): grupo que se abandonará.
  /// Output:
  /// - `Future<void>`: termina al actualizar el grupo.
  /// Resumen:
  /// - Quita al usuario de los integrantes y de los nombres del grupo.
  Future<void> salirDeGrupo(Grupo grupo) async{
    await _grupos.doc(grupo.codigo).update({
      'integrantes': FieldValue.arrayRemove([uid]),
      'nombres.$uid': FieldValue.delete(),
    });
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea nueva o editada.
  /// Output:
  /// - `Future<TareaGrupal>`: tarea guardada, con su ID si era nueva.
  /// Resumen:
  /// - Valida y crea la tarea, o actualiza solo los campos del formulario
  ///   para no pisar el estado, documentos ni notas de otros integrantes.
  Future<TareaGrupal> guardarTarea(TareaGrupal tarea) async{
    if(tarea.titulo.trim().isEmpty){
      throw ArgumentError('Debes rellenar el título.');
    }
    if(tarea.asignatura.trim().isEmpty){
      throw ArgumentError('Debes rellenar la asignatura.');
    }
    for(final subtarea in tarea.subtareas){
      if(subtarea.titulo.trim().isEmpty){
        throw ArgumentError('Debes rellenar las subtareas.');
      }
    }

    if(tarea.id == null){
      final referencia = await _tareas(tarea.grupo).add(tarea.toMap());
      return tarea.copyWith(id: referencia.id);
    }
    await _tareas(tarea.grupo).doc(tarea.id).update({
      'titulo': tarea.titulo,
      'asignatura': tarea.asignatura,
      'fechaLimite': Timestamp.fromDate(tarea.fechaLimite),
      'subtareas': [for(final s in tarea.subtareas) s.toMap()],
    });
    return tarea;
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se actualizará.
  /// - `estado` (`EstadoTarea`): nuevo estado.
  /// Output:
  /// - `Future<void>`: termina al guardar el cambio.
  /// Resumen:
  /// - Cambia el estado de la tarea para todos los integrantes.
  Future<void> cambiarEstado(TareaGrupal tarea, EstadoTarea estado) async{
    await _tareas(tarea.grupo).doc(tarea.id).update({'estado': estado.name});
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que contiene la subtarea.
  /// - `indice` (`int`): posición de la subtarea.
  /// - `completada` (`bool`): nuevo valor de la subtarea.
  /// Output:
  /// - `Future<void>`: termina al confirmar la transacción.
  /// Resumen:
  /// - Marca una subtarea dentro de una transacción para no perder cambios
  ///   simultáneos de otros integrantes.
  Future<void> marcarSubtarea(
    TareaGrupal tarea,
    int indice,
    bool completada,
  ) async{
    final referencia = _tareas(tarea.grupo).doc(tarea.id);
    await _db.runTransaction((transaccion) async{
      final documento = await transaccion.get(referencia);
      final datos = documento.data();
      if(datos == null){
        throw StateError('La tarea ya no existe.');
      }
      final actual = TareaGrupal.fromMap(tarea.grupo, documento.id, datos);
      if(indice >= actual.subtareas.length ||
          actual.subtareas[indice].titulo != tarea.subtareas[indice].titulo){
        throw StateError('Las subtareas cambiaron. Vuelve a intentarlo.');
      }
      final subtareas = [...actual.subtareas];
      subtareas[indice] = Subtarea(
        titulo: subtareas[indice].titulo,
        completada: completada,
      );
      transaccion.update(referencia, {
        'subtareas': [for(final s in subtareas) s.toMap()],
      });
    });
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se compartirá el enlace.
  /// - `documento` (`Documento`): nombre y enlace escritos por el usuario.
  /// Output:
  /// - `Future<void>`: termina al guardar el enlace.
  /// Resumen:
  /// - Valida el enlace, le agrega `https://` si falta y lo guarda.
  Future<void> agregarDocumento(TareaGrupal tarea, Documento documento) async{
    if(documento.titulo.trim().isEmpty){
      throw ArgumentError('Debes escribir un nombre para el documento.');
    }
    var enlace = documento.enlace.trim();
    if(!enlace.contains('://')) enlace = 'https://$enlace';
    final uri = Uri.tryParse(enlace);
    if(uri == null || !uri.hasAuthority){
      throw ArgumentError('El enlace no es válido.');
    }
    final limpio = Documento(titulo: documento.titulo.trim(), enlace: enlace);
    await _tareas(tarea.grupo).doc(tarea.id).update({
      'documentos': FieldValue.arrayUnion([limpio.toMap()]),
    });
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se compartirá el archivo.
  /// - `nombre` (`String`): nombre del archivo con su extensión.
  /// - `bytes` (`Uint8List`): contenido del archivo.
  /// - `onProgreso` (`void Function(double)?`): avance entre 0 y 1.
  /// Output:
  /// - `Future<void>`: termina al guardar el archivo y su documento.
  /// Resumen:
  /// - Divide el archivo en trozos de 700 KB, los guarda en Firestore y
  ///   borra los trozos subidos si algo falla.
  Future<void> subirArchivo(
    TareaGrupal tarea, {
    required String nombre,
    required Uint8List bytes,
    void Function(double progreso)? onProgreso,
  }) async{
    final punto = nombre.lastIndexOf('.');
    final extension = punto == -1 ? '' : nombre.substring(punto + 1).toLowerCase();
    if(!extensionesArchivo.contains(extension)){
      throw ArgumentError('Ese tipo de archivo no está permitido.');
    }
    if(bytes.length > tamanoMaximo){
      throw ArgumentError('El archivo supera el máximo de 5 MB.');
    }

    final archivo = _archivos(tarea).doc().id;
    final partes = (bytes.length / _tamanoParte).ceil();
    try{
      for(var i = 0; i < partes; i++){
        final inicio = i * _tamanoParte;
        final fin = min(inicio + _tamanoParte, bytes.length);
        await _partes(tarea, archivo).doc(i.toString().padLeft(3, '0')).set({
          'datos': Blob(Uint8List.sublistView(bytes, inicio, fin)),
        });
        onProgreso?.call((i + 1) / partes);
      }
      final documento = Documento(
        titulo: nombre,
        enlace: '',
        ruta: archivo,
        tamano: bytes.length,
      );
      await _tareas(tarea.grupo).doc(tarea.id).update({
        'documentos': FieldValue.arrayUnion([documento.toMap()]),
      });
    } catch(_){
      await _borrarPartes(tarea, archivo).catchError((_){});
      rethrow;
    }
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña del archivo.
  /// - `documento` (`Documento`): archivo que se descargará.
  /// Output:
  /// - `Future<Uint8List>`: contenido completo del archivo.
  /// Resumen:
  /// - Lee los trozos en orden y los junta en un solo arreglo de bytes.
  Future<Uint8List> descargarArchivo(
    TareaGrupal tarea,
    Documento documento,
  ) async{
    final consulta = await _partes(tarea, documento.ruta!).get();
    if(consulta.docs.isEmpty && (documento.tamano ?? 0) > 0){
      throw StateError('El archivo ya no está disponible.');
    }
    final datos = BytesBuilder(copy: false);
    for(final parte in consulta.docs){
      datos.add((parte.data()['datos'] as Blob).bytes);
    }
    return datos.takeBytes();
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña del archivo.
  /// - `archivo` (`String`): ID del archivo.
  /// Output:
  /// - `Future<void>`: termina al borrar todos los trozos.
  /// Resumen:
  /// - Elimina en un solo lote los trozos guardados de un archivo.
  Future<void> _borrarPartes(TareaGrupal tarea, String archivo) async{
    final consulta = await _partes(tarea, archivo).get();
    final lote = _db.batch();
    for(final parte in consulta.docs){
      lote.delete(parte.reference);
    }
    await lote.commit();
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que contiene el documento.
  /// - `documento` (`Documento`): enlace o archivo que se quitará.
  /// Output:
  /// - `Future<void>`: termina al quitarlo de la tarea.
  /// Resumen:
  /// - Quita el documento de la tarea y, si es un archivo, borra sus trozos.
  Future<void> eliminarDocumento(TareaGrupal tarea, Documento documento) async{
    await _tareas(tarea.grupo).doc(tarea.id).update({
      'documentos': FieldValue.arrayRemove([documento.toMap()]),
    });
    if(documento.ruta != null) await _borrarPartes(tarea, documento.ruta!);
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se publicará la nota.
  /// - `texto` (`String`): contenido de la nota.
  /// Output:
  /// - `Future<void>`: termina al guardar la nota.
  /// Resumen:
  /// - Publica una nota con el nombre del usuario y la fecha actual.
  Future<void> agregarNota(TareaGrupal tarea, String texto) async{
    if(texto.trim().isEmpty){
      throw ArgumentError('Debes escribir la nota.');
    }
    final nota = Nota(
      autorId: uid,
      autor: _nombreUsuario,
      texto: texto.trim(),
      fecha: DateTime.now(),
    );
    await _tareas(tarea.grupo).doc(tarea.id).update({
      'notas': FieldValue.arrayUnion([nota.toMap()]),
    });
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que contiene la nota.
  /// - `nota` (`Nota`): nota que se borrará.
  /// Output:
  /// - `Future<void>`: termina al quitar la nota.
  /// Resumen:
  /// - Elimina una nota de la tarea.
  Future<void> eliminarNota(TareaGrupal tarea, Nota nota) async{
    await _tareas(tarea.grupo).doc(tarea.id).update({
      'notas': FieldValue.arrayRemove([nota.toMap()]),
    });
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se eliminará.
  /// Output:
  /// - `Future<void>`: termina al borrar la tarea y sus archivos.
  /// Resumen:
  /// - Borra los archivos de la tarea y luego la tarea para todo el grupo.
  Future<void> eliminarTarea(TareaGrupal tarea) async{
    for(final documento in tarea.documentos){
      if(documento.ruta != null) await _borrarPartes(tarea, documento.ruta!);
    }
    await _tareas(tarea.grupo).doc(tarea.id).delete();
  }
}
