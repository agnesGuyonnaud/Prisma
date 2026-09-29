import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import '../widgets/importancia_slider.dart';
import 'tarea_formulario.dart';

/// Detalle de la tarea seleccionada, con cambios persistidos en SQLite.
// StatefulWidget permite actualizar la vista al marcar o desmarcar subtareas.
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
  bool _guardando = false;
  int? _importanciaTemporal;

  @override
  void initState() {
    super.initState();
    _tarea = widget.tarea;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _editar() async {
    final editada = await Navigator.of(context).push<Tarea>(
      MaterialPageRoute(
        builder: (_) =>
            TareaFormulario(repositorio: widget.repositorio, tarea: _tarea),
      ),
    );
    if (mounted && editada != null) setState(() => _tarea = editada);
  }

  Future<void> _guardarCambio(Tarea actualizada) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final guardada = await widget.repositorio.guardar(actualizada);
      if (mounted) setState(() => _tarea = guardada);
    } catch (_) {
      if (mounted) {
        _mostrarError('No se pudo guardar el cambio. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarImportancia(int valor) async {
    // El deslizador responde al movimiento, pero escribe solo al soltarlo.
    if (valor != _tarea.importancia) {
      await _guardarCambio(_tarea.copyWith(importancia: valor));
    }
    // Si falló la escritura, vuelve a mostrar el último valor guardado.
    if (mounted) setState(() => _importanciaTemporal = null);
  }

  Future<void> _eliminar() async {
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
      await widget.repositorio.eliminar(_tarea.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _mostrarError('No se pudo eliminar la tarea. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El tema pertenece solo a esta vista: no requiere cambios en main.dart.
    // Conserva el modo claro/oscuro de la aplicación y genera pares de colores
    // de fondo y texto a partir del morado de referencia.
    final colores = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6674E8),
      primary: const Color(0xFF6674E8),
      secondary: const Color(0xFFBAE147),
      brightness: Theme.of(context).brightness,
    );
    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: colores),
      // Builder proporciona un contexto que ya incluye el tema local.
      child: Builder(builder: _construirDetalle),
    );
  }

  Widget _construirDetalle(BuildContext context) {
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
          // La flecha vuelve a la ruta anterior. Si se usa como pantalla inicial
          // de prueba, queda deshabilitada porque todavía no hay dónde volver.
          leading: IconButton(
            tooltip: 'Volver',
            icon: const BackButtonIcon(),
            onPressed: !_guardando && Navigator.of(context).canPop()
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          actions: [
            // Editar queda accesible en la barra y libera espacio vertical.
            // El tooltip también proporciona una etiqueta de accesibilidad.
            IconButton(
              tooltip: 'Editar',
              onPressed: _guardando ? null : _editar,
              icon: const Icon(Icons.edit_outlined),
            ),
            // Las acciones secundarias quedan en un menú siempre accesible,
            // sin reservar una franja inferior exclusivamente para Eliminar.
            PopupMenuButton<String>(
              enabled: !_guardando,
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_vert),
              onSelected: (accion) {
                if (accion == 'eliminar') {
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
          // El contenido se desplaza y el menú permanece en la barra superior.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              // Evita estirar la tarjeta demasiado en tabletas o escritorio.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                // Card.filled aporta la superficie tonal y la forma de Material 3.
                // Sustituye la tarjeta personalizada con una franja lateral.
                child: Card.filled(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Conservamos título y asignatura en una sola fila.
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
                              // Chip es una etiqueta informativa, sin acción de
                              // filtro o selección asociada a la asignatura.
                              child: Chip(
                                // Usamos el par primaryContainer/onPrimaryContainer
                                // para una etiqueta morada con contraste tonal.
                                backgroundColor: const Color(0xFFBAE147),
                                side: BorderSide.none,
                                // Un texto más grande y seminegrita mejora la
                                // lectura de la asignatura en pantallas móviles.
                                labelStyle: textos.labelLarge?.copyWith(
                                  color: colores.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                                label: Text(
                                  _tarea.asignatura,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Un widget reutilizable mantiene alineados los datos.
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
                        // El estado puede cambiarse sin abrir todo el formulario.
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
                        // Filas contiguas con casilla a la izquierda. Conservamos
                        // las áreas táctiles estándar; no encogemos las casillas.
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
                                : (valor) {
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

// Widget privado y reutilizable para mostrar icono, etiqueta y valor.
// Es StatelessWidget porque no necesita guardar ni modificar estado propio.
class _DatoTarea extends StatelessWidget {
  const _DatoTarea({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      // Espaciado basado en múltiplos de 8 para mantener un ritmo uniforme.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 24, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          // Permite que los valores largos ocupen varias líneas sin desbordarse.
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
