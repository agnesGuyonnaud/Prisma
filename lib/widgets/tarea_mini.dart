import 'package:flutter/material.dart';

/// Tarjeta compacta para insertar en la lista de tareas del home.
///
/// Presenta datos sin modificarlos ni guardarlos. La acción opcional [onTap]
/// permite que el home decida qué hacer al tocarla, por ejemplo abrir el detalle.
/// El contenedor que la utilice se encarga del ancho y de separar las tarjetas.
///
/// Ejemplo:
/// ```dart
/// const TareaMini(
///   titulo: 'Tarea 1',
///   asignatura: 'Aplicaciones móviles',
///   fechaLimite: '30 sep · 23:59',
///   tipo: 'Proyecto',
///   totalSubtareas: 3,
/// )
/// ```
class TareaMini extends StatelessWidget {
  const TareaMini({
    super.key,
    required this.titulo,
    required this.asignatura,
    required this.fechaLimite,
    required this.tipo,
    this.colorAsignatura = const Color(0xFF4834B6),
    this.completada = false,
    this.totalSubtareas = 0,
    this.subtareasCompletadas = 0,
    this.onTap,
  }) : assert(totalSubtareas >= 0),
       assert(subtareasCompletadas >= 0),
       assert(subtareasCompletadas <= totalSubtareas);

  final String titulo;
  final String asignatura;

  // La fecha llega como texto ya preparado; esta vista no calcula plazos.
  final String fechaLimite;
  final String tipo;
  final Color colorAsignatura;
  final bool completada;
  final int totalSubtareas;
  final int subtareasCompletadas;

  // Sin callback, conserva su comportamiento puramente visual.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Reutiliza la tipografía y las superficies del tema del home.
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    // El color de cada asignatura genera un par de fondo/texto para su etiqueta.
    final coloresAsignatura = ColorScheme.fromSeed(
      seedColor: colorAsignatura,
      brightness: tema.brightness,
    );

    // Misma variante tonal que el detalle: fondo del tema, sin borde exterior.
    return Card.filled(
      // El home ya aporta los 16 dp laterales; no se añade otro margen aquí.
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // InkWell añade respuesta visual al toque y permite activar con teclado.
      // Al estar dentro de Card, su efecto queda contenido por los bordes.
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y asignatura comparten fila, como en el wireframe.
              // Los textos largos se acortan para conservar el formato compacto.
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      titulo,
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
                    child: Chip(
                      backgroundColor: coloresAsignatura.primaryContainer,
                      side: BorderSide.none,
                      labelStyle: tema.textTheme.labelLarge?.copyWith(
                        color: coloresAsignatura.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      label: Text(
                        asignatura,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _DatoMini(
                icono: Icons.calendar_today_outlined,
                etiqueta: 'Fecha límite',
                valor: fechaLimite,
              ),
              const SizedBox(height: 8),
              _DatoMini(
                icono: Icons.description_outlined,
                etiqueta: 'Tipo',
                valor: tipo,
              ),
              const Divider(height: 16),
              // La casilla es solo un indicador visual, no un control interactivo.
              // Semantics comunica su estado sin anunciar una acción inexistente.
              Row(
                children: [
                  Semantics(
                    label: 'Tarea completada',
                    checked: completada,
                    child: Icon(
                      completada
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: completada
                          ? colores.primary
                          : colores.onSurfaceVariant,
                    ),
                  ),
                  if (totalSubtareas > 0) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$subtareasCompletadas de $totalSubtareas subtareas',
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

// Fila de información secundaria: icono a la izquierda y texto a la derecha.
class _DatoMini extends StatelessWidget {
  const _DatoMini({
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
