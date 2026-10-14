import 'package:flutter/material.dart';

class TareaMini extends StatelessWidget {
  const TareaMini({
    super.key,
    required this.titulo,
    required this.asignatura,
    required this.fechaLimite,
    required this.tipo,
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
  final Color colorAsignatura;
  final bool completada;
  final int totalSubtareas;
  final int subtareasCompletadas;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    final coloresAsignatura = ColorScheme.fromSeed(
      seedColor: colorAsignatura,
      brightness: tema.brightness,
    );

    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,
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
  Widget build(BuildContext context){
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
