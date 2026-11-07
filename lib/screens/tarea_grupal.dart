// File y Directory para guardar los archivos descargados.
import 'dart:io';

// FirebaseException para mostrar el error real de Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
// Selector de archivos del teléfono.
import 'package:file_picker/file_picker.dart';
// Widgets de Material Design 3.
import 'package:flutter/material.dart';
// Clipboard para copiar enlaces.
import 'package:flutter/services.dart';
// Abre un archivo con la app que corresponda (PDF, Word, etc.).
import 'package:open_filex/open_filex.dart';
// Carpeta temporal de la app.
import 'package:path_provider/path_provider.dart';
// Abre los enlaces en el navegador.
import 'package:url_launcher/url_launcher.dart';

// Operaciones de la tarea grupal en Firestore.
import '../data/grupos_repository.dart';
// Repositorio local que se pasa al formulario.
import '../data/tareas_repository.dart';
// Grupo, TareaGrupal, Documento y Nota.
import '../models/grupo_model.dart';
// EstadoTarea para el selector de estado.
import '../models/tarea_model.dart';
// Formato de fechas.
import '../utils/fecha_tarea.dart';
// Función iniciales para los avatares.
import '../widgets/tarea_grupal_mini.dart';
// Formulario para editar la tarea.
import 'tarea_grupal_formulario.dart';

class TareaGrupalScreen extends StatefulWidget{
  const TareaGrupalScreen({
    super.key,
    required this.tarea,
    required this.grupo,
    required this.repositorio,
    this.grupos,
    this.colorAsignatura,
  });

  final TareaGrupal tarea;
  final Grupo grupo;
  final TareasRepository repositorio;
  final GruposRepository? grupos;
  final Color? colorAsignatura;

  @override
  State<TareaGrupalScreen> createState() => _TareaGrupalScreenState();
}

class _TareaGrupalScreenState extends State<TareaGrupalScreen>{
  late final GruposRepository _grupos;
  late final Stream<TareaGrupal?> _cambios;
  final _nota = TextEditingController();
  bool _guardando = false;
  String? _subiendo;
  double _progresoSubida = 0;

  @override
  void initState(){
    super.initState();
    _grupos = widget.grupos ?? GruposRepository.instancia;
    _cambios = _grupos.tarea(widget.tarea.grupo, widget.tarea.id!);
  }

  @override
  void dispose(){
    _nota.dispose();
    super.dispose();
  }

  /// Input:
  /// - `mensaje` (`String`): texto que se mostrará al usuario.
  /// Output:
  /// - `void`: muestra un aviso en la pantalla.
  /// Resumen:
  /// - Reemplaza el aviso actual por uno nuevo.
  void _mostrarMensaje(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Input:
  /// - `accion` (`Future<void> Function()`): operación que se ejecutará.
  /// - `error` (`String`): mensaje si falla por un motivo desconocido.
  /// Output:
  /// - `Future<bool>`: `true` si la acción terminó bien.
  /// Resumen:
  /// - Bloquea la pantalla mientras corre la acción y muestra el error real
  ///   (validación, permisos de Firebase u otro) si falla.
  Future<bool> _ejecutar(Future<void> Function() accion, String error) async{
    if(_guardando) return false;
    setState(() => _guardando = true);
    try{
      await accion();
      return true;
    } on ArgumentError catch(e){
      if(mounted) _mostrarMensaje(e.message.toString());
    } on StateError catch(e){
      if(mounted) _mostrarMensaje(e.message);
    } on FirebaseException catch(e){
      debugPrint('Firebase ${e.code}: ${e.message}');
      if(mounted){
        _mostrarMensaje(
          e.code == 'permission-denied'
              ? 'Firebase rechazó la operación por permisos. Revisa que las reglas de Firestore estén publicadas.'
              : '$error (${e.code})',
        );
      }
    } catch(e){
      debugPrint('Error en tarea grupal: $e');
      if(mounted) _mostrarMensaje(error);
    } finally{
      if(mounted) setState(() => _guardando = false);
    }
    return false;
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se editará.
  /// Output:
  /// - `Future<void>`: termina al cerrar el formulario.
  /// Resumen:
  /// - Abre el formulario de edición; los cambios llegan por el stream.
  Future<void> _editar(TareaGrupal tarea) async{
    await Navigator.of(context).push<TareaGrupal>(
      MaterialPageRoute(
        builder: (_) => TareaGrupalFormulario(
          grupos: [widget.grupo],
          repositorio: widget.repositorio,
          gruposRepositorio: _grupos,
          tarea: tarea,
        ),
      ),
    );
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se eliminará.
  /// Output:
  /// - `Future<void>`: termina al cancelar o eliminar.
  /// Resumen:
  /// - Pide confirmación, borra la tarea para todo el grupo y vuelve atrás.
  Future<void> _eliminar(TareaGrupal tarea) async{
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('¿Eliminar tarea grupal?'),
        content: Text(
          'Se eliminará “${tarea.titulo}” para todos los integrantes de ${widget.grupo.nombre}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if(confirmado != true || !mounted) return;
    final listo = await _ejecutar(
      () => _grupos.eliminarTarea(tarea),
      'No se pudo eliminar la tarea. Inténtalo otra vez.',
    );
    if(listo && mounted) Navigator.of(context).pop();
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se compartirá el enlace.
  /// Output:
  /// - `Future<void>`: termina al guardar o cancelar.
  /// Resumen:
  /// - Pide nombre y enlace en un diálogo y lo guarda en la tarea.
  Future<void> _agregarDocumento(TareaGrupal tarea) async{
    final documento = await showDialog<Documento>(
      context: context,
      builder: (_) => const _DialogoDocumento(),
    );
    if(documento == null || !mounted) return;
    await _ejecutar(
      () => _grupos.agregarDocumento(tarea, documento),
      'No se pudo añadir el documento.',
    );
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se compartirá el archivo.
  /// Output:
  /// - `Future<void>`: termina al subir el archivo o cancelar.
  /// Resumen:
  /// - Abre el selector de archivos, revisa el tamaño y sube el archivo
  ///   mostrando el progreso.
  Future<void> _subirArchivo(TareaGrupal tarea) async{
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: GruposRepository.extensionesArchivo,
    );
    if(archivo == null || !mounted) return;
    final tamano = await archivo.length();
    if(tamano != null && tamano > GruposRepository.tamanoMaximo){
      if(mounted) _mostrarMensaje('El archivo supera el máximo de 5 MB.');
      return;
    }
    if(!mounted) return;
    setState((){
      _subiendo = archivo.name;
      _progresoSubida = 0;
    });
    final listo = await _ejecutar(() async{
      final bytes = await archivo.readAsBytes();
      await _grupos.subirArchivo(
        tarea,
        nombre: archivo.name,
        bytes: bytes,
        onProgreso: (progreso){
          if(mounted) setState(() => _progresoSubida = progreso);
        },
      );
    }, 'No se pudo subir el archivo. Revisa tu conexión.');
    if(!mounted) return;
    setState(() => _subiendo = null);
    if(listo) _mostrarMensaje('“${archivo.name}” compartido con el grupo.');
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña del documento.
  /// - `documento` (`Documento`): enlace o archivo tocado.
  /// Output:
  /// - `Future<void>`: termina al abrirlo o mostrar un error.
  /// Resumen:
  /// - Abre los archivos en el teléfono y los enlaces en el navegador.
  Future<void> _abrirDocumento(TareaGrupal tarea, Documento documento) async{
    if(documento.esArchivo){
      await _abrirArchivo(tarea, documento);
      return;
    }
    var abierto = false;
    try{
      abierto = await launchUrl(
        Uri.parse(documento.enlace),
        mode: LaunchMode.externalApplication,
      );
    } catch(_){
      abierto = false;
    }
    if(!abierto && mounted){
      _mostrarMensaje('No se pudo abrir “${documento.titulo}”.');
    }
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea dueña del archivo.
  /// - `documento` (`Documento`): archivo que se abrirá.
  /// Output:
  /// - `Future<void>`: termina al abrir el archivo o mostrar un error.
  /// Resumen:
  /// - Descarga el archivo a la carpeta temporal (si no estaba guardado)
  ///   y lo abre con la app correspondiente del teléfono.
  Future<void> _abrirArchivo(TareaGrupal tarea, Documento documento) async{
    late final File archivo;
    final listo = await _ejecutar(() async{
      final carpeta = Directory(
        '${(await getTemporaryDirectory()).path}/archivos/${documento.ruta}',
      );
      archivo = File('${carpeta.path}/${documento.titulo}');
      if(await archivo.exists() && await archivo.length() == documento.tamano){
        return;
      }
      if(mounted) _mostrarMensaje('Descargando “${documento.titulo}”…');
      final bytes = await _grupos.descargarArchivo(tarea, documento);
      await carpeta.create(recursive: true);
      await archivo.writeAsBytes(bytes, flush: true);
    }, 'No se pudo descargar el archivo. Revisa tu conexión.');
    if(!listo || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final resultado = await OpenFilex.open(archivo.path);
    if(!mounted) return;
    if(resultado.type == ResultType.noAppToOpen){
      _mostrarMensaje('No tienes una app para abrir archivos .${documento.extension}.');
    } else if(resultado.type != ResultType.done){
      _mostrarMensaje('No se pudo abrir “${documento.titulo}”.');
    }
  }

  /// Input:
  /// - `documento` (`Documento`): enlace que se copiará.
  /// Output:
  /// - `Future<void>`: termina al copiar.
  /// Resumen:
  /// - Copia el enlace al portapapeles y avisa al usuario.
  Future<void> _copiarEnlace(Documento documento) async{
    await Clipboard.setData(ClipboardData(text: documento.enlace));
    if(mounted) _mostrarMensaje('Enlace de “${documento.titulo}” copiado.');
  }

  /// Input:
  /// - `bytes` (`int`): tamaño del archivo.
  /// Output:
  /// - `String`: tamaño legible en B, KB o MB.
  /// Resumen:
  /// - Formatea el tamaño que se muestra bajo cada archivo.
  String _formatearTamano(int bytes){
    if(bytes < 1024) return '$bytes B';
    if(bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  /// Input:
  /// - `documento` (`Documento`): enlace o archivo.
  /// Output:
  /// - `IconData`: ícono según el tipo de archivo.
  /// Resumen:
  /// - Elige el ícono de PDF, texto, presentación, planilla, imagen o enlace.
  IconData _iconoDocumento(Documento documento){
    if(!documento.esArchivo) return Icons.link;
    return switch(documento.extension){
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' || 'txt' => Icons.article_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
      'png' || 'jpg' || 'jpeg' => Icons.image_outlined,
      'zip' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea donde se publicará la nota.
  /// Output:
  /// - `Future<void>`: termina al publicar o si el texto está vacío.
  /// Resumen:
  /// - Publica la nota escrita y limpia el campo de texto.
  Future<void> _enviarNota(TareaGrupal tarea) async{
    final texto = _nota.text;
    if(texto.trim().isEmpty) return;
    final listo = await _ejecutar(
      () => _grupos.agregarNota(tarea, texto),
      'No se pudo publicar la nota.',
    );
    if(listo){
      _nota.clear();
      if(mounted) FocusScope.of(context).unfocus();
    }
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema y navegación.
  /// Output:
  /// - `Widget`: pantalla de detalle de la tarea grupal.
  /// Resumen:
  /// - Escucha la tarea en tiempo real y construye la barra superior con
  ///   sus acciones y el contenido (o un aviso si fue eliminada).
  @override
  Widget build(BuildContext context){
    return StreamBuilder<TareaGrupal?>(
      stream: _cambios,
      initialData: widget.tarea,
      builder: (context, snapshot){
        final tarea = snapshot.data;
        return PopScope(
          canPop: !_guardando,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Tarea grupal'),
              centerTitle: false,
              titleSpacing: 16,
              leading: IconButton(
                tooltip: 'Volver',
                icon: const BackButtonIcon(),
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              actions: [
                if(tarea != null) ...[
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: _guardando ? null : () => _editar(tarea),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_guardando,
                    tooltip: 'Más opciones',
                    onSelected: (_) => _eliminar(tarea),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Eliminar',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: snapshot.hasError
                  ? const Center(child: Text('No se pudo cargar la tarea.'))
                  : tarea == null
                  ? const Center(
                      child: Text('Esta tarea fue eliminada por el grupo.'),
                    )
                  : _construirDetalle(context, tarea),
            ),
          ),
        );
      },
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto con el tema actual.
  /// - `tarea` (`TareaGrupal`): versión más reciente de la tarea.
  /// Output:
  /// - `Widget`: contenido desplazable del detalle.
  /// Resumen:
  /// - Construye la información, el estado, los colaboradores y las
  ///   secciones de subtareas, documentos y notas.
  Widget _construirDetalle(BuildContext context, TareaGrupal tarea){
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final textos = tema.textTheme;
    final color = widget.colorAsignatura ?? colores.secondaryContainer;
    final colorTexto = widget.colorAsignatura == null
        ? colores.onSecondaryContainer
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final completadas = tarea.subtareasCompletadas;
    final miUid = _grupos.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card.filled(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                tarea.titulo,
                                style: textos.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Chip(
                                backgroundColor: color,
                                side: BorderSide.none,
                                labelStyle: textos.labelLarge?.copyWith(
                                  color: colorTexto,
                                  fontWeight: FontWeight.w600,
                                ),
                                label: Text(
                                  tarea.asignatura,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Dato(
                          icono: Icons.groups_outlined,
                          etiqueta: 'Grupo',
                          valor: widget.grupo.nombre,
                        ),
                        _Dato(
                          icono: Icons.calendar_today_outlined,
                          etiqueta: 'Fecha límite',
                          valor: fechaTarea(tarea.fechaLimite),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estado',
                          style: textos.labelMedium?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<EstadoTarea>(
                            showSelectedIcon: false,
                            segments: [
                              for(final estado in EstadoTarea.values)
                                ButtonSegment(
                                  value: estado,
                                  label: Text(
                                    estado.etiqueta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            selected: {tarea.estado},
                            onSelectionChanged: _guardando
                                ? null
                                : (seleccion) => _ejecutar(
                                    () => _grupos.cambiarEstado(
                                      tarea,
                                      seleccion.first,
                                    ),
                                    'No se pudo cambiar el estado.',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Colaboradores',
                          style: textos.labelMedium?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for(final nombre in widget.grupo.nombresIntegrantes)
                              Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: colores.secondaryContainer,
                                  child: Text(
                                    iniciales(nombre),
                                    style: textos.labelSmall?.copyWith(
                                      color: colores.onSecondaryContainer,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                label: Text(nombre),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Seccion(
                  icono: Icons.checklist,
                  titulo: 'Subtareas',
                  children: [
                    if(tarea.subtareas.isEmpty)
                      Text(
                        'Esta tarea no tiene subtareas.',
                        style: textos.bodyMedium?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      Text(
                        '$completadas de ${tarea.subtareas.length} completadas',
                        style: textos.bodySmall?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completadas / tarea.subtareas.length,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                    ],
                    for(var i = 0; i < tarea.subtareas.length; i++)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: tarea.subtareas[i].completada,
                        title: Text(
                          tarea.subtareas[i].titulo,
                          style: textos.bodyMedium?.copyWith(
                            decoration: tarea.subtareas[i].completada
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        onChanged: _guardando
                            ? null
                            : (valor) => _ejecutar(
                                () => _grupos.marcarSubtarea(
                                  tarea,
                                  i,
                                  valor ?? false,
                                ),
                                'No se pudo actualizar la subtarea.',
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _Seccion(
                  icono: Icons.folder_shared_outlined,
                  titulo: 'Documentos',
                  children: [
                    if(tarea.documentos.isEmpty && _subiendo == null)
                      Text(
                        'Sube archivos (PDF, Word, PowerPoint, Excel, texto o imágenes de hasta 5 MB) o comparte enlaces del trabajo.',
                        style: textos.bodyMedium?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                    for(final documento in tarea.documentos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colores.tertiaryContainer,
                          child: Icon(
                            _iconoDocumento(documento),
                            color: colores.onTertiaryContainer,
                          ),
                        ),
                        title: Text(
                          documento.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          documento.esArchivo
                              ? [
                                  documento.extension.toUpperCase(),
                                  if(documento.tamano != null)
                                    _formatearTamano(documento.tamano!),
                                ].join(' · ')
                              : documento.enlace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: _guardando
                            ? null
                            : () => _abrirDocumento(tarea, documento),
                        onLongPress: documento.esArchivo
                            ? null
                            : () => _copiarEnlace(documento),
                        trailing: IconButton(
                          tooltip: 'Quitar documento',
                          onPressed: _guardando
                              ? null
                              : () => _ejecutar(
                                  () => _grupos.eliminarDocumento(
                                    tarea,
                                    documento,
                                  ),
                                  'No se pudo quitar el documento.',
                                ),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    if(_subiendo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subiendo “$_subiendo”… ${(_progresoSubida * 100).round()} %',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textos.bodySmall?.copyWith(
                                color: colores.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _progresoSubida,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _guardando
                              ? null
                              : () => _subirArchivo(tarea),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir archivo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _guardando
                              ? null
                              : () => _agregarDocumento(tarea),
                          icon: const Icon(Icons.add_link),
                          label: const Text('Añadir enlace'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Seccion(
                  icono: Icons.sticky_note_2_outlined,
                  titulo: 'Notas',
                  children: [
                    if(tarea.notas.isEmpty)
                      Text(
                        'Deja notas para coordinar el trabajo con tu grupo.',
                        style: textos.bodyMedium?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                    for(final nota in tarea.notas)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colores.secondaryContainer,
                          child: Text(
                            iniciales(nota.autor),
                            style: textos.labelMedium?.copyWith(
                              color: colores.onSecondaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          '${nota.autor} · ${fechaTarea(nota.fecha, corta: true)}',
                          style: textos.labelMedium?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                        subtitle: Text(nota.texto, style: textos.bodyMedium),
                        trailing: nota.autorId == miUid
                            ? IconButton(
                                tooltip: 'Borrar nota',
                                onPressed: _guardando
                                    ? null
                                    : () => _ejecutar(
                                        () => _grupos.eliminarNota(tarea, nota),
                                        'No se pudo borrar la nota.',
                                      ),
                                icon: const Icon(Icons.delete_outline),
                              )
                            : null,
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nota,
                      enabled: !_guardando,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe una nota para el grupo',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Publicar nota',
                          onPressed: _guardando
                              ? null
                              : () => _enviarNota(tarea),
                          icon: const Icon(Icons.send),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget{
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: tarjeta delineada con título e ícono.
  /// Resumen:
  /// - Agrupa el contenido de una sección del detalle.
  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Text(titulo, style: tema.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget{
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: fila con ícono, etiqueta y valor.
  /// Resumen:
  /// - Construye una fila de información del detalle.
  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 24, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: tema.textTheme.labelMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(valor, style: tema.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoDocumento extends StatefulWidget{
  const _DialogoDocumento();

  @override
  State<_DialogoDocumento> createState() => _DialogoDocumentoState();
}

class _DialogoDocumentoState extends State<_DialogoDocumento>{
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _enlace = TextEditingController();

  @override
  void dispose(){
    _titulo.dispose();
    _enlace.dispose();
    super.dispose();
  }

  /// Input:
  /// - `valor` (`String?`): contenido del campo que se validará.
  /// Output:
  /// - `String?`: mensaje si está vacío o `null` si tiene contenido.
  /// Resumen:
  /// - Valida que el campo obligatorio contenga texto.
  String? _obligatorio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Completa este campo' : null;

  /// Input:
  /// - No recibe parámetros; usa los campos del diálogo.
  /// Output:
  /// - `void`: cierra el diálogo con el documento escrito.
  /// Resumen:
  /// - Valida los campos y devuelve el nombre y enlace.
  void _aceptar(){
    if(!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(
      Documento(titulo: _titulo.text.trim(), enlace: _enlace.text.trim()),
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y navegación.
  /// Output:
  /// - `Widget`: diálogo para compartir un enlace.
  /// Resumen:
  /// - Construye el formulario con nombre y enlace del documento.
  @override
  Widget build(BuildContext context){
    return AlertDialog(
      icon: const Icon(Icons.add_link),
      title: const Text('Compartir enlace'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titulo,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Informe final',
                border: OutlineInputBorder(),
              ),
              validator: _obligatorio,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _enlace,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace',
                hintText: 'docs.google.com/…',
                border: OutlineInputBorder(),
              ),
              validator: _obligatorio,
              onFieldSubmitted: (_) => _aceptar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Compartir')),
      ],
    );
  }
}
