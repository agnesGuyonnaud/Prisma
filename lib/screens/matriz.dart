import 'package:flutter/material.dart';
import 'package:prisma/screens/home.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/navegacion_principal.dart';
import '../widgets/matriz_tareas.dart';
import '../widgets/tarea_list.dart';
import 'perfil.dart';
import 'pomodoro.dart';
import 'tarea_formulario.dart';

class MatrizScreen extends StatefulWidget {
  const MatrizScreen({super.key, this.repositorio});

  final TareasRepository? repositorio;

  @override
  State<MatrizScreen> createState() => _MatrizScreenState();
}

class _MatrizScreenState extends State<MatrizScreen> with RouteAware {
  late final TareasRepository _repositorio;
  late Future<List<Tarea>> _tareas;
  ModalRoute<dynamic>? _ruta;

  @override
  void initState(){
    super.initState();
    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _tareas = _repositorio.listar();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta != _ruta){
      if (_ruta != null) tareasRouteObserver.unsubscribe(this);
      _ruta = ruta;
      if (ruta != null) tareasRouteObserver.subscribe(this, ruta);
    }
  }

  @override
  void didPopNext() => _recargar();

  @override
  void dispose(){
    tareasRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _recargar(){
    if (!mounted) return;
    final consulta = _repositorio.listar();
    setState((){
      _tareas = consulta;
    });
  }

  Future<void> _abrirInicio() async{
    if (!mounted) return;
    await abrirInicioConservandoPila(
      context,
      builder: (_) => HomeScreen(repositorio: _repositorio),
    );
  }

  Future<void> _abrirPomodoro() async{
    if (!mounted) return;
    await navegarAPantallaPrincipal(
      context,
      ruta: rutaPomodoro,
      builder: (_) => PomodoroScreen(repositorio: _repositorio),
    );
  }

  Future<void> _crearTarea() async{
    await Navigator.of(context).push<Tarea>(
      MaterialPageRoute(
        builder: (_) => TareaFormulario(repositorio: _repositorio),
      ),
    );
  }

  void _abrirPerfil(){
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilScreen(repositorio: _repositorio),
      ),
    );
  }

  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Matriz de Eisenhower - matriz screen',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  GestureDetector(
                    onTap: _abrirPerfil,
                    child: Semantics(
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
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Expanded(
                child: FutureBuilder<List<Tarea>>(
                  future: _tareas,
                  builder: (context, snapshot){
                    if (snapshot.connectionState != ConnectionState.done){
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError){
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
                    return MatrizTareas(tareas: tareas);
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearTarea,
        icon: const Icon(Icons.add),
        label: const Text('Añadir tarea'),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: ColoredBox(
        color: colores.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NavigationBar(
            backgroundColor: colores.surfaceContainer,
            selectedIndex: 1,
            onDestinationSelected: (index){
              if (index == 0) _abrirInicio();
              if (index == 2) _abrirPomodoro();
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
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
