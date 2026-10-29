import 'package:flutter/material.dart';

import '../data/google_calendar_sync.dart';
import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import '../widgets/importancia_slider.dart';
import 'tarea_formulario.dart';

class TareaScreen extends StatefulWidget {
  const TareaScreen({
    super.key,
    required this.tarea,
    required this.repositorio,
  });

  final Tarea tarea;
  final TareasRepository repositorio;

  @override
  State<TareaScreen> createState() => _TareaScreenState();
}

class _TareaScreenState extends State<TareaScreen> {
  late Tarea _tarea;
  late Future<Color?> _colorAsignatura;
  bool _guardando = false;
  int? _importanciaTemporal;

  @override
  void initState(){
    super.initState();
    _tarea = widget.tarea;
    _colorAsignatura = _buscarColorAsignatura(_tarea.asignatura);
  }

  /// Input:
  /// - `nombre` (`String`): nombre de la asignatura asociada a la tarea.
  /// Output:
  /// - `Future<Color?>`: color encontrado o `null` si no existe la asignatura.
  /// Resumen:
  /// - Busca el color de la asignatura en el repositorio.
  Future<Color?> _buscarColorAsignatura(String nombre) async{
    final asignaturas = await widget.repositorio.listarAsignaturas();
    for (final asignatura in asignaturas){
      if (asignatura.nombre == nombre) return asignatura.color;
    }
    return null;
  }

  /// Input:
  /// - `mensaje` (`String`): texto que se mostrará al usuario.
  /// Output:
  /// - `void`: muestra un aviso en la pantalla.
  /// Resumen:
  /// - Presenta el error en una notificación temporal.
  void _mostrarError(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Input:
  /// - No recibe parámetros; usa la tarea actual y el repositorio.
  /// Output:
  /// - `Future<void>`: termina cuando se cierra el formulario de edición.
  /// Resumen:
  /// - Abre el formulario y actualiza la tarea si se guardan cambios.
  Future<void> _editar() async{
    final editada = await Navigator.of(context).push<Tarea>(
      MaterialPageRoute(
        builder: (_) =>
            TareaFormulario(repositorio: widget.repositorio, tarea: _tarea),
      ),
    );
    if (mounted && editada != null){
      setState((){
        _tarea = editada;
        _colorAsignatura = _buscarColorAsignatura(_tarea.asignatura);
      });
    }
  }

  /// Input:
  /// - `actualizada` (`Tarea`): datos de la tarea que se guardarán.
  /// Output:
  /// - `Future<void>`: termina tras guardar y sincronizar, o mostrar un error.
  /// Resumen:
  /// - Persiste la tarea y sincroniza su evento de Calendar si está habilitado.
  Future<void> _guardarCambio(Tarea actualizada) async{
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final guardada = await widget.repositorio.guardar(actualizada);
      if (mounted) setState(() => _tarea = guardada);
      try{
        await GoogleCalendarSync(
          repositorio: widget.repositorio,
        ).sincronizarTareaSiHabilitada(guardada);
      } on GoogleCalendarSyncException catch (error){
        if (mounted){
          _mostrarError(
            'La tarea se guardó, pero no se sincronizó con Calendar: '
            '${error.message}',
          );
        }
      }
    } catch (_){
      if (mounted){
        _mostrarError('No se pudo guardar el cambio. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Input:
  /// - `valor` (`int`): nueva importancia de la tarea.
  /// Output:
  /// - `Future<void>`: termina después del guardado y actualización visual.
  /// Resumen:
  /// - Guarda la importancia elegida y limpia el valor temporal del control.
  Future<void> _cambiarImportancia(int valor) async{
    if (valor != _tarea.importancia){
      await _guardarCambio(_tarea.copyWith(importancia: valor));
    }

    if (mounted) setState(() => _importanciaTemporal = null);
  }

  /// Input:
  /// - No recibe parámetros; usa la tarea y el repositorio de esta pantalla.
  /// Output:
  /// - `Future<void>`: termina al cancelar o completar la eliminación.
  /// Resumen:
  /// - Confirma, elimina el evento de Calendar si corresponde y borra la tarea.
  Future<void> _eliminar() async{
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text(
          'Se eliminarán “${_tarea.titulo}” y sus subtareas del dispositivo.',
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
    if (confirmado != true || !mounted) return;
    setState(() => _guardando = true);
    try {
      await GoogleCalendarSync(
        repositorio: widget.repositorio,
      ).eliminarEventoSiHabilitado(_tarea.id!);
      await widget.repositorio.eliminar(_tarea.id!);
      if (mounted) Navigator.of(context).pop();
    } on GoogleCalendarSyncException catch (error){
      if (mounted) _mostrarError(error.message);
    } catch (_){
      if (mounted){
        _mostrarError('No se pudo eliminar la tarea. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema y árbol de widgets.
  /// Output:
  /// - `Widget`: devuelve la pantalla tematizada con los detalles de la tarea.
  /// Resumen:
  /// - Define los colores de la pantalla y delega la construcción del detalle.
  @override
  Widget build(BuildContext context){
    final colores = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6674E8),
      primary: const Color(0xFF6674E8),
      secondary: const Color(0xFFBAE147),
      brightness: Theme.of(context).brightness,
    );
    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: colores),

      child: Builder(builder: _construirDetalle),
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto con el tema y estado actual.
  /// Output:
  /// - `Widget`: devuelve el contenido de detalle y acciones de la tarea.
  /// Resumen:
  /// - Construye la información editable y el resumen de la tarea.
  Widget _construirDetalle(BuildContext context){
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final textos = tema.textTheme;
    final completadas = _tarea.subtareasCompletadas;

    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: colores.surface,
        appBar: AppBar(
          title: const Text('Detalle de tarea'),
          centerTitle: false,
          titleSpacing: 16,

          leading: IconButton(
            tooltip: 'Volver',
            icon: const BackButtonIcon(),
            onPressed: !_guardando && Navigator.of(context).canPop()
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          actions: [
            IconButton(
              tooltip: 'Editar',
              onPressed: _guardando ? null : _editar,
              icon: const Icon(Icons.edit_outlined),
            ),

            PopupMenuButton<String>(
              enabled: !_guardando,
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_vert),
              onSelected: (accion){
                if (accion == 'eliminar'){
                  _eliminar();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: colores.error),
                      const SizedBox(width: 16),
                      Text('Eliminar', style: TextStyle(color: colores.error)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),

                child: Card.filled(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _tarea.titulo,
                                style: textos.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 2,

                              child: FutureBuilder<Color?>(
                                future: _colorAsignatura,
                                builder: (context, snapshot){
                                  final color =
                                      snapshot.data ?? const Color(0xFFBAE147);
                                  final colorTexto =
                                      ThemeData.estimateBrightnessForColor(
                                            color,
                                          ) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black;
                                  return Tooltip(
                                    message: snapshot.hasError
                                        ? 'No se pudo cargar el color de la asignatura'
                                        : _tarea.asignatura,
                                    child: Chip(
                                      backgroundColor: color,
                                      side: BorderSide.none,
                                      labelStyle: textos.labelLarge?.copyWith(
                                        color: colorTexto,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                      label: Text(
                                        _tarea.asignatura,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _DatoTarea(
                          icono: Icons.calendar_today_outlined,
                          etiqueta: 'Fecha límite',
                          valor: fechaTarea(_tarea.fechaLimite),
                        ),
                        _DatoTarea(
                          icono: Icons.description_outlined,
                          etiqueta: 'Tipo',
                          valor: _tarea.tipo,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ImportanciaSlider(
                            valor: _importanciaTemporal ?? _tarea.importancia,
                            onChanged: _guardando
                                ? null
                                : (valor) => setState(
                                    () => _importanciaTemporal = valor,
                                  ),
                            onChangeEnd: _guardando
                                ? null
                                : _cambiarImportancia,
                          ),
                        ),

                        PopupMenuButton<EstadoTarea>(
                          enabled: !_guardando,
                          tooltip: 'Cambiar estado',
                          initialValue: _tarea.estado,
                          onSelected: (estado) =>
                              _guardarCambio(_tarea.copyWith(estado: estado)),
                          itemBuilder: (_) => [
                            for (final estado in EstadoTarea.values)
                              PopupMenuItem(
                                value: estado,
                                child: Text(estado.etiqueta),
                              ),
                          ],
                          child: _DatoTarea(
                            icono: Icons.timelapse_outlined,
                            etiqueta: 'Estado · toca para cambiar',
                            valor: _tarea.estado.etiqueta,
                          ),
                        ),
                        const Divider(height: 32),
                        Text('Subtareas', style: textos.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _tarea.subtareas.isEmpty
                              ? 'Esta tarea no tiene subtareas.'
                              : '$completadas de ${_tarea.subtareas.length} completadas',
                          style: textos.bodySmall?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),

                        for (var i = 0; i < _tarea.subtareas.length; i++)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            visualDensity: VisualDensity.standard,
                            value: _tarea.subtareas[i].completada,
                            title: Text(
                              _tarea.subtareas[i].titulo,
                              style: textos.bodyMedium?.copyWith(
                                decoration: _tarea.subtareas[i].completada
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            onChanged: _guardando
                                ? null
                                : (valor){
                                    final subtareas = [..._tarea.subtareas];
                                    subtareas[i] = Subtarea(
                                      titulo: subtareas[i].titulo,
                                      completada: valor ?? false,
                                    );
                                    _guardarCambio(
                                      _tarea.copyWith(subtareas: subtareas),
                                    );
                                  },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatoTarea extends StatelessWidget {
  const _DatoTarea({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema y árbol de widgets.
  /// Output:
  /// - `Widget`: devuelve la fila con el icono, etiqueta y valor del dato.
  /// Resumen:
  /// - Construye una fila accesible de información del detalle de tarea.
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
