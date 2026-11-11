// Widgets de Material Design 3.
import 'package:flutter/material.dart';

// Grupo y TareaGrupal que muestra la tarjeta.
import '../models/grupo_model.dart';
// EstadoTarea para la etiqueta de estado.
import '../models/tarea_model.dart';
// Formato de la fecha límite.
import '../utils/fecha_tarea.dart';

/// Input:
/// - `nombre` (`String`): nombre de una persona o grupo.
/// Output:
/// - `String`: hasta dos iniciales en mayúscula, o `"?"` si está vacío.
/// Resumen:
/// - Obtiene las iniciales que se muestran en los avatares.
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

class TareaGrupalMini extends StatelessWidget {
  const TareaGrupalMini({
    super.key,
    required this.tarea,
    this.grupo,
    this.colorAsignatura,
    this.onTap,
  });

  final TareaGrupal tarea;
  final Grupo? grupo;
  final Color? colorAsignatura;
  final VoidCallback? onTap;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: tarjeta de la tarea grupal.
  /// Resumen:
  /// - Construye la tarjeta con asignatura, grupo, fecha,
  ///   estado, progreso de subtareas y colaboradores.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final color = colorAsignatura ?? colores.secondaryContainer;
    final colorTexto = colorAsignatura == null
        ? colores.onSecondaryContainer
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final detalle = [
      if (grupo != null) grupo!.nombre,
      fechaTarea(tarea.fechaLimite, corta: true),
    ].join(' · ');

    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tarea.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Chip(
                      backgroundColor: color,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: tema.textTheme.labelMedium?.copyWith(
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
              const SizedBox(height: 4),
              Text(
                detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: colores.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  EstadoEtiqueta(estado: tarea.estado),
                  if (tarea.subtareas.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.checklist,
                      size: 16,
                      color: colores.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tarea.subtareasCompletadas}/${tarea.subtareas.length}',
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (grupo != null) ...[
                    Text(
                      'Colaboradores',
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AvataresIntegrantes(nombres: grupo!.nombresIntegrantes),
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

class EstadoEtiqueta extends StatelessWidget {
  const EstadoEtiqueta({super.key, required this.estado});

  final EstadoTarea estado;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: etiqueta con ícono y texto del estado.
  /// Resumen:
  /// - Muestra el estado con un color distinto para cada valor.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final (fondo, texto, icono) = switch (estado) {
      EstadoTarea.pendiente => (
        colores.surfaceContainerHighest,
        colores.onSurfaceVariant,
        Icons.radio_button_unchecked,
      ),
      EstadoTarea.enProgreso => (
        colores.tertiaryContainer,
        colores.onTertiaryContainer,
        Icons.timelapse,
      ),
      EstadoTarea.completada => (
        colores.primaryContainer,
        colores.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: texto),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: tema.textTheme.labelSmall?.copyWith(color: texto),
          ),
        ],
      ),
    );
  }
}

class AvataresIntegrantes extends StatelessWidget {
  const AvataresIntegrantes({
    super.key,
    required this.nombres,
    this.maximo = 3,
  });

  final List<String> nombres;
  final int maximo;

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y árbol de widgets.
  /// Output:
  /// - `Widget`: fila de avatares superpuestos.
  /// Resumen:
  /// - Muestra las iniciales de hasta `maximo` integrantes y un contador
  ///   con los restantes.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final visibles = nombres.take(maximo).toList();
    final restantes = nombres.length - visibles.length;
    final cantidad = visibles.length + (restantes > 0 ? 1 : 0);

    /// Input:
    /// - `texto` (`String`): iniciales o contador.
    /// - `fondo`, `frente` (`Color`): colores del avatar y del texto.
    /// Output:
    /// - `Widget`: avatar circular con borde.
    /// Resumen:
    /// - Construye un avatar pequeño de la fila.
    Widget avatar(String texto, Color fondo, Color frente) {
      return Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: colores.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundColor: fondo,
          child: Text(
            texto,
            style: tema.textTheme.labelSmall?.copyWith(
              color: frente,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Colaboradores: ${nombres.join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        width: cantidad == 0 ? 0 : 27.0 + (cantidad - 1) * 18,
        height: 27,
        child: Stack(
          children: [
            for (var i = 0; i < visibles.length; i++)
              Positioned(
                left: i * 18,
                child: avatar(
                  iniciales(visibles[i]),
                  colores.secondaryContainer,
                  colores.onSecondaryContainer,
                ),
              ),
            if (restantes > 0)
              Positioned(
                left: visibles.length * 18,
                child: avatar(
                  '+$restantes',
                  colores.primary,
                  colores.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
