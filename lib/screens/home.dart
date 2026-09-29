import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import '../widgets/tarea_mini.dart';
import 'tarea.dart';
import 'tarea_formulario.dart';

/// Home que consulta las tareas locales y abre sus formularios y detalles.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repositorio});

  final TareasRepository? repositorio;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TareasRepository _repositorio;
  late Future<List<Tarea>> _tareas;

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _tareas = _repositorio.listar();
  }

  void _recargar() {
    if (!mounted) return;
    final consulta = _repositorio.listar();
    setState(() {
      _tareas = consulta;
    });
  }

  Future<void> _crearTarea() async {
    final guardada = await Navigator.of(context).push<Tarea>(
      MaterialPageRoute(
        builder: (_) => TareaFormulario(repositorio: _repositorio),
      ),
    );
    if (guardada != null) _recargar();
  }

  Future<void> _abrirTarea(Tarea tarea) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TareaScreen(tarea: tarea, repositorio: _repositorio),
      ),
    );
    // Refleja las ediciones, los cambios de subtareas y las eliminaciones.
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        // Un único margen exterior de 16 dp alinea el saludo, el perfil y
        // las tareas, también cuando la ventana supera los 600 dp de ancho.
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            // Permite desplazar la última tarjeta por encima del FAB.
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hola, estudiante',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Indicador de perfil decorativo, sin acción.
                  Semantics(
                    label: 'Perfil',
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: colores.secondaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: colores.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Tareas', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              // Solo texto de referencia: todavía no abre una lista.
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver todas las tareas →',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Tarea>>(
                future: _tareas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Text('No se pudieron cargar tus tareas.'),
                        TextButton(
                          onPressed: _recargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    );
                  }
                  final tareas = snapshot.data ?? [];
                  if (tareas.isEmpty) {
                    return const Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aún no tienes tareas. Pulsa “Añadir tarea” para crear la primera.',
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final tarea in tareas)
                        Padding(
                          key: ValueKey(tarea.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TareaMini(
                            titulo: tarea.titulo,
                            asignatura: tarea.asignatura,
                            fechaLimite: fechaTarea(
                              tarea.fechaLimite,
                              corta: true,
                            ),
                            tipo: tarea.tipo,
                            completada: tarea.estado == EstadoTarea.completada,
                            totalSubtareas: tarea.subtareas.length,
                            subtareasCompletadas: tarea.subtareasCompletadas,
                            onTap: () => _abrirTarea(tarea),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // El formulario guarda en SQLite antes de devolver la nueva tarea.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearTarea,
        icon: const Icon(Icons.add),
        label: const Text('Añadir tarea'),
      ),
      // endFloat ya aporta 16 dp desde el borde seguro: no duplicar el margen.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Barra de referencia visual: Inicio permanece seleccionado.
      // Sin onDestinationSelected, las opciones no cambian la vista ni la selección.
      // El fondo llega al borde; el contenido conserva 16 dp a cada lado.
      bottomNavigationBar: ColoredBox(
        color: colores.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NavigationBar(
            backgroundColor: colores.surfaceContainer,
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                label: 'Matriz',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                label: 'Pomodoro',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                label: 'Grupos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
