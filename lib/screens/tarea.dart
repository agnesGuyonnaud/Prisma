import 'package:flutter/material.dart';

/// Detalle de una tarea con datos de ejemplo y subtareas interactivas.
// StatefulWidget permite actualizar la vista al marcar o desmarcar subtareas.
class TareaScreen extends StatefulWidget {
  const TareaScreen({super.key});

  @override
  State<TareaScreen> createState() => _TareaScreenState();
}

class _TareaScreenState extends State<TareaScreen> {
  // Más adelante, estos datos pueden provenir de la tarea seleccionada.
  final _subtareas = <String>[
    'Revisar los requerimientos',
    'Diseñar la vista de tareas',
    'Revisar la entrega con el grupo',
  ];
  // Cada posición corresponde a la subtarea del mismo índice.
  // Los cambios son locales a esta pantalla; todavía no se guardan.
  final _completadas = <bool>[false, false, false];

  // Editar y eliminar siguen siendo acciones de demostración.
  // La cascada (..) oculta el aviso anterior antes de mostrar el siguiente.
  void _mostrarAviso(String accion) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$accion estará disponible próximamente.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    // El tema pertenece solo a esta vista: no requiere cambios en main.dart.
    // Conserva el modo claro/oscuro de la aplicación y genera pares de colores
    // de fondo y texto a partir del morado de referencia.
    final colores = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4834B6),
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
    final completadas = _completadas.where((valor) => valor).length;

    return Scaffold(
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
          onPressed: Navigator.of(context).canPop()
              ? () => Navigator.of(context).maybePop()
              : null,
        ),
        actions: [
          // Editar queda accesible en la barra y libera espacio vertical.
          // El tooltip también proporciona una etiqueta de accesibilidad.
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _mostrarAviso('Editar la tarea'),
            icon: const Icon(Icons.edit_outlined),
          ),
          // Las acciones secundarias quedan en un menú siempre accesible,
          // sin reservar una franja inferior exclusivamente para Eliminar.
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert),
            onSelected: (accion) {
              if (accion == 'eliminar') {
                _mostrarAviso('Eliminar la tarea');
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
                            child: Text('Tarea 1', style: textos.titleLarge),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            // Chip es una etiqueta informativa, sin acción de
                            // filtro o selección asociada a la asignatura.
                            child: Chip(
                              // Usamos el par primaryContainer/onPrimaryContainer
                              // para una etiqueta morada con contraste tonal.
                              backgroundColor: colores.primaryContainer,
                              side: BorderSide.none,
                              // Un texto más grande y seminegrita mejora la
                              // lectura de la asignatura en pantallas móviles.
                              labelStyle: textos.labelLarge?.copyWith(
                                color: colores.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              label: const Text(
                                'Aplicaciones móviles',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Un widget reutilizable mantiene alineados los datos.
                      // El estado es fijo por ahora: marcar subtareas no lo cambia.
                      const _DatoTarea(
                        icono: Icons.calendar_today_outlined,
                        etiqueta: 'Fecha límite',
                        valor: '30 de septiembre de 2026 · 23:59',
                      ),
                      const _DatoTarea(
                        icono: Icons.description_outlined,
                        etiqueta: 'Tipo',
                        valor: 'Proyecto',
                      ),
                      const _DatoTarea(
                        icono: Icons.flag_outlined,
                        etiqueta: 'Importancia',
                        valor: 'Alta',
                      ),
                      const _DatoTarea(
                        icono: Icons.timelapse_outlined,
                        etiqueta: 'Estado',
                        valor: 'En progreso',
                      ),
                      const Divider(height: 32),
                      Text('Subtareas', style: textos.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '$completadas de ${_subtareas.length} completadas',
                        style: textos.bodySmall?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Filas contiguas con casilla a la izquierda. Conservamos
                      // las áreas táctiles estándar; no encogemos las casillas.
                      for (var i = 0; i < _subtareas.length; i++)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.standard,
                          value: _completadas[i],
                          title: Text(
                            _subtareas[i],
                            style: textos.bodyMedium?.copyWith(
                              decoration: _completadas[i]
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          onChanged: (valor) {
                            // setState actualiza la casilla, el tachado y el
                            // contador. Si valor es null, usamos false.
                            setState(() => _completadas[i] = valor ?? false);
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
