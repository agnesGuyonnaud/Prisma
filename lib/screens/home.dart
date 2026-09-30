import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../widgets/tarea_list.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera fija: no forma parte de la lista desplazable.
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
              // El ListView solo contiene la lista de tareas.
              Expanded(
                child: FutureBuilder<List<Tarea>>(
                  future: _tareas,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No se pudieron cargar tus tareas.'),
                            TextButton(
                              onPressed: _recargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }
                    final tareas = snapshot.data ?? [];
                    if (tareas.isEmpty) {
                      return const Align(
                        alignment: Alignment.topCenter,
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aún no tienes tareas. Pulsa “Añadir tarea” para crear la primera.',
                            ),
                          ),
                        ),
                      );
                    }
                    final now = DateTime.now();
                    final tareasOrdenadas = [...tareas]
                      ..sort(
                        (a, b) => b
                            .getImportanceEmergencyScore(now)
                            .compareTo(a.getImportanceEmergencyScore(now)),
                      );
                    return TareaList(
                      tareasOrdenadas: tareasOrdenadas,
                      repositorio: _repositorio,
                    );
                  },
                ),
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
      // (bottomNavigationBar sin cambios)
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
