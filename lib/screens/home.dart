import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/meta_estudio_semanal.dart';
import '../utils/navegacion_principal.dart';
import '../widgets/tarea_list.dart';
import 'matriz.dart';
import 'perfil.dart';
import 'pomodoro.dart';
import 'tarea_formulario.dart';

import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repositorio});

  final TareasRepository? repositorio;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final TareasRepository _repositorio;
  late Future<List<MetaEstudioSemanal>> _progresosMetas;
  final _horasMetaController = TextEditingController();
  ModalRoute<dynamic>? _ruta;

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _progresosMetas = _cargarProgresosMetas();
  }

  @override
  void dispose() {
    tareasRouteObserver.unsubscribe(this);
    _horasMetaController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta != _ruta) {
      if (_ruta != null) tareasRouteObserver.unsubscribe(this);
      _ruta = ruta;
      if (ruta != null) tareasRouteObserver.subscribe(this, ruta);
    }
  }

  @override
  void didPopNext() => _recargarProgresosMetas();

  Future<List<MetaEstudioSemanal>> _cargarProgresosMetas() async {
    final asignaturasFuture = _repositorio.listarAsignaturas();
    final metasFuture = _repositorio.listarMetasSemanales();
    final tiemposFuture = _repositorio.obtenerTiempoEstudioSemanal();
    final asignaturas = await asignaturasFuture;
    final metas = await metasFuture;
    final tiempos = await tiemposFuture;
    return [
      for (final asignatura in asignaturas)
        MetaEstudioSemanal(
          asignatura: asignatura,
          segundosMeta: metas[asignatura.nombre],
          segundosEstudiados: tiempos[asignatura.nombre] ?? 0,
        ),
    ];
  }

  void _recargarProgresosMetas() {
    setState(() {
      _progresosMetas = _cargarProgresosMetas();
    });
  }

  String get _nombre {
    final nombre = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? "";
    return nombre.isEmpty ? "estudiante" : nombre.split(" ").first;
  }

  Future<void> _crearTarea() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TareaFormulario(repositorio: _repositorio),
      ),
    );
  }

  Future<void> _abrirMatriz() async {
    if (!mounted) return;
    await navegarAPantallaPrincipal(
      context,
      ruta: rutaMatriz,
      builder: (_) => MatrizScreen(repositorio: _repositorio),
    );
  }

  Future<void> _abrirPomodoro() async {
    if (!mounted) return;
    await navegarAPantallaPrincipal(
      context,
      ruta: rutaPomodoro,
      builder: (_) => PomodoroScreen(repositorio: _repositorio),
    );
    if (mounted) _recargarProgresosMetas();
  }

  Future<void> _editarMeta(MetaEstudioSemanal progreso) async {
    final horasActuales = progreso.segundosMeta == null
        ? ''
        : (progreso.segundosMeta! / Duration.secondsPerHour)
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.?0+$'), '');
    _horasMetaController.text = horasActuales;
    final formKey = GlobalKey<FormState>();
    final horas = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Meta semanal: ${progreso.asignatura.nombre}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _horasMetaController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Horas de estudio por semana',
              suffixText: 'h',
              border: OutlineInputBorder(),
            ),
            validator: (valor) {
              final cantidad = double.tryParse(
                (valor ?? '').trim().replaceAll(',', '.'),
              );
              if (cantidad == null || cantidad <= 0 || cantidad > 168) {
                return 'Ingresa una cantidad entre 0 y 168 horas.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(
                double.parse(
                  _horasMetaController.text.trim().replaceAll(',', '.'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(
                double.parse(
                  _horasMetaController.text.trim().replaceAll(',', '.'),
                ),
              );
            },
            child: const Text('Guardar meta'),
          ),
        ],
      ),
    );
    if (horas == null || !mounted) return;
    try {
      await _repositorio.guardarMetaSemanal(
        asignatura: progreso.asignatura.nombre,
        segundos: (horas * Duration.secondsPerHour).round(),
      );
      if (!mounted) return;
      _recargarProgresosMetas();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meta semanal guardada para ${progreso.asignatura.nombre}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la meta: $error')),
      );
    }
  }

  String _formatearTiempo(int segundos) {
    final horas = segundos ~/ Duration.secondsPerHour;
    final minutos = (segundos % Duration.secondsPerHour) ~/ 60;
    return '$horas:${minutos.toString().padLeft(2, '0')}';
  }

  void _abrirPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilScreen(repositorio: _repositorio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      'Hola, $_nombre',
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
              const SizedBox(height: 16),
              FutureBuilder<List<MetaEstudioSemanal>>(
                future: _progresosMetas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        title: const Text('Meta de estudio semanal'),
                        subtitle: const Text(
                          'No se pudieron cargar las metas.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Reintentar',
                          onPressed: _recargarProgresosMetas,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      child: SizedBox(
                        height: 104,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final progresos = snapshot.data ?? [];
                  return Card(
                    color: colores.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'META DE ESTUDIO SEMANAL',
                                  style: tema.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                'Semana',
                                style: tema.textTheme.labelSmall?.copyWith(
                                  color: colores.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (progresos.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Añade una asignatura para definir una meta semanal.',
                              ),
                            )
                          else
                            SizedBox(
                              height: 91,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: progresos.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final progreso = progresos[index];
                                  final meta = progreso.segundosMeta;
                                  final fraccion = progreso.progreso;
                                  return SizedBox(
                                    width: 92,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _editarMeta(progreso),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: 42,
                                            height: 42,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: fraccion,
                                                  strokeWidth: 3,
                                                  backgroundColor:
                                                      colores.outlineVariant,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        progreso
                                                            .asignatura
                                                            .color,
                                                      ),
                                                ),
                                                Text(
                                                  '${progreso.porcentaje}%',
                                                  style: tema
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            progreso.asignatura.nombre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: tema.textTheme.labelSmall,
                                          ),
                                          Text(
                                            meta == null
                                                ? 'Definir meta'
                                                : '${_formatearTiempo(progreso.segundosEstudiados)} / '
                                                      '${_formatearTiempo(meta)} h',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: tema.textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      colores.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Tareas', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(child: TareaList(repositorio: _repositorio)),
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
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 1) _abrirMatriz();
              if (index == 2) _abrirPomodoro();
            },
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
