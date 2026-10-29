import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';

class TareaMini extends StatefulWidget {
  const TareaMini({
    super.key,
    required this.titulo,
    required this.asignatura,
    required this.fechaLimite,
    required this.tipo,
    this.repositorio,
    this.colorAsignatura = const Color(0xFFBAE147),
    this.completada = false,
    this.totalSubtareas = 0,
    this.subtareasCompletadas = 0,
    this.onTap,
  }) : assert(totalSubtareas >= 0),
       assert(subtareasCompletadas >= 0),
       assert(subtareasCompletadas <= totalSubtareas);

  final String titulo;
  final String asignatura;
  final String fechaLimite;
  final String tipo;
  final TareasRepository? repositorio;
  final Color colorAsignatura;
  final bool completada;
  final int totalSubtareas;
  final int subtareasCompletadas;

  final VoidCallback? onTap;

  @override
  State<TareaMini> createState() => _TareaMiniState();
}

class _TareaMiniState extends State<TareaMini> {
  late Future<Color?> _colorAsignatura;

  /// Input:
  /// - No recibe parámetros; consulta el repositorio inyectado o el singleton.
  /// Output:
  /// - `TareasRepository`: repositorio asociado a la tarjeta.
  /// Resumen:
  /// - Centraliza la selección del repositorio para cargar datos de asignatura.
  TareasRepository get _repositorio =>
      widget.repositorio ?? TareasRepository.instancia;

  @override
  void initState() {
    super.initState();
    _colorAsignatura = _buscarColorAsignatura();
  }

  @override
  void didUpdateWidget(covariant TareaMini oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asignatura != widget.asignatura ||
        oldWidget.repositorio != widget.repositorio) {
      _colorAsignatura = _buscarColorAsignatura();
    }
  }

  /// Input:
  /// - No recibe parámetros; usa la asignatura y repositorio de la tarjeta.
  /// Output:
  /// - `Future<Color?>`: color de la asignatura o `null` si no existe.
  /// Resumen:
  /// - Busca el color que se utilizará para identificar la asignatura.
  Future<Color?> _buscarColorAsignatura() async {
    final asignaturas = await _repositorio.listarAsignaturas();
    for (final asignatura in asignaturas) {
      if (asignatura.nombre == widget.asignatura) return asignatura.color;
    }
    return null;
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: tarjeta resumida con título, asignatura y datos de tarea.
  /// Resumen:
  /// - Construye la tarjeta compacta con estado y progreso de subtareas.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 3,
                    child: FutureBuilder<Color?>(
                      future: _colorAsignatura,
                      builder: (context, snapshot) {
                        final color = snapshot.data ?? widget.colorAsignatura;
                        final colorTexto =
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black;
                        return Tooltip(
                          message: snapshot.hasError
                              ? 'No se pudo cargar el color de la asignatura'
                              : widget.asignatura,
                          child: Chip(
                            backgroundColor: color,
                            side: BorderSide.none,
                            labelStyle: tema.textTheme.labelLarge?.copyWith(
                              color: colorTexto,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            label: Text(
                              widget.asignatura,
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
              const SizedBox(height: 4),
              _DatoMini(
                icono: Icons.calendar_today_outlined,
                etiqueta: 'Fecha límite',
                valor: widget.fechaLimite,
              ),
              const SizedBox(height: 8),
              _DatoMini(
                icono: Icons.description_outlined,
                etiqueta: 'Tipo',
                valor: widget.tipo,
              ),
              const Divider(height: 16),

              Row(
                children: [
                  Semantics(
                    label: 'Tarea completada',
                    checked: widget.completada,
                    child: Icon(
                      widget.completada
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: widget.completada
                          ? colores.primary
                          : colores.onSurfaceVariant,
                    ),
                  ),
                  if (widget.totalSubtareas > 0) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.subtareasCompletadas} de ${widget.totalSubtareas} subtareas',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoMini extends StatelessWidget {
  const _DatoMini({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y accesibilidad.
  /// Output:
  /// - `Widget`: fila accesible con icono, etiqueta y valor.
  /// Resumen:
  /// - Construye una línea compacta de información de la tarea.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Semantics(
      label: '$etiqueta: $valor',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icono, size: 16, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
