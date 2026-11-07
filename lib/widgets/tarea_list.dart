// StreamSubscription para escuchar las tareas grupales.
import 'dart:async';

import 'package:flutter/material.dart';

// Sincroniza las tareas grupales con Google Calendar.
import '../data/google_calendar_sync.dart';
// Tareas grupales en Firestore.
import '../data/grupos_repository.dart';
import '../data/tareas_repository.dart';
// ResumenGrupos y TareaGrupal.
import '../models/grupo_model.dart';
import '../models/tarea_model.dart';
import '../models/cadran.dart';
import '../utils/fecha_tarea.dart';
// Tarjeta de tarea grupal.
import 'tarea_grupal_mini.dart';
import 'tarea_mini.dart';
import '../screens/tarea.dart';
// Detalle de la tarea grupal.
import '../screens/tarea_grupal.dart';

final RouteObserver<ModalRoute<dynamic>> tareasRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class TareaList extends StatefulWidget {
  const TareaList({super.key, this.repositorio, this.cadran});

  final TareasRepository? repositorio;
  final Cadran? cadran;

  @override
  State<TareaList> createState() => _TareaListState();
}

class _TareaListState extends State<TareaList> with RouteAware {
  late Future<List<Tarea>> _tareas;
  ModalRoute<dynamic>? _ruta;

  late final TareasRepository _repositorio;
  StreamSubscription<ResumenGrupos>? _suscripcionGrupos;
  ResumenGrupos? _resumen;
  Map<String, Color> _colores = {};

  @override
  void initState(){
    super.initState();

    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _tareas = _repositorio.listar();
    if(widget.cadran == null) _escucharGrupos();
  }

  /// Input:
  /// - No recibe parámetros; usa el repositorio de grupos y el local.
  /// Output:
  /// - `void`: inicia la suscripción y la carga de colores.
  /// Resumen:
  /// - Escucha las tareas grupales para mostrarlas en Inicio y carga los
  ///   colores de las asignaturas.
  void _escucharGrupos(){
    _suscripcionGrupos = GruposRepository.instancia.resumen().listen((resumen){
      if(!mounted) return;
      setState(() => _resumen = resumen);
      _sincronizarCalendar(resumen);
    }, onError: (_){});
    _repositorio.listarAsignaturas().then((asignaturas){
      if(!mounted) return;
      setState(() => _colores = {for(final a in asignaturas) a.nombre: a.color});
    });
  }

  /// Input:
  /// - `resumen` (`ResumenGrupos`): tareas grupales actuales.
  /// Output:
  /// - `Future<void>`: termina al sincronizar o fallar.
  /// Resumen:
  /// - Sincroniza las tareas grupales con Calendar sin mostrar errores en Inicio.
  Future<void> _sincronizarCalendar(ResumenGrupos resumen) async{
    try{
      await GoogleCalendarSync(
        repositorio: _repositorio,
      ).sincronizarTareasGrupalesSiHabilitada(resumen.tareas);
    } on GoogleCalendarSyncException{
      return;
    }
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
  void didPopNext(){
    _recargar();
  }

  @override
  void dispose(){
    tareasRouteObserver.unsubscribe(this);
    _suscripcionGrupos?.cancel();
    super.dispose();
  }

  /// Input:
  /// - No recibe parámetros; consulta el repositorio de esta lista.
  /// Output:
  /// - `void`: actualiza la futura consulta de tareas.
  /// Resumen:
  /// - Vuelve a cargar tareas cuando se regresa a esta ruta.
  void _recargar(){
    final repositorio = _repositorio;
    if (!mounted) return;
    final consulta = repositorio.listar();
    setState((){
      _tareas = consulta;
    });
  }

  /// Input:
  /// - `tareas` (`List<Tarea>`): tareas candidatas para filtrar.
  /// - `cadran` (`Cadran`): criterios de importancia y urgencia.
  /// Output:
  /// - `List<Tarea>`: tareas que corresponden al cuadrante.
  /// Resumen:
  /// - Filtra las tareas según sus valores de importancia y urgencia.
  List<Tarea> _filterByCadran(List<Tarea> tareas, Cadran cadran) =>
      tareas.where((tarea){
        final importante = tarea.importancia >= 3;
        return importante == cadran.importante &&
            tarea.isUrgente() == cadran.urgente;
      }).toList();

  /// Input:
  /// - `context` (`BuildContext`): contexto para construir la lista.
  /// Output:
  /// - `Widget`: contenido de carga, error, vacío o lista de tareas.
  /// Resumen:
  /// - Carga y ordena tareas, aplicando el filtro de cuadrante si corresponde.
  @override
  Widget build(BuildContext context){
    return FutureBuilder<List<Tarea>>(
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
        final resumen = _resumen;
        final grupales = resumen?.tareas ?? <TareaGrupal>[];
        if (tareas.isEmpty && grupales.isEmpty){
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
        final tareasToDisplay = (widget.cadran != null)
            ? _filterByCadran(tareas, widget.cadran!)
            : tareas;

        if (tareasToDisplay.isEmpty && grupales.isEmpty){
          return Center(child: Text('No hay tareas en este cuadrante.'));
        }

        final tareasOrdenadas = [...tareasToDisplay]
          ..sort(
            (a, b) => b
                .getImportanceEmergencyScore(now)
                .compareTo(a.getImportanceEmergencyScore(now)),
          );
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount:
              tareasOrdenadas.length +
              (grupales.isEmpty ? 0 : grupales.length + 1),
          itemBuilder: (context, index){
            if(index == tareasOrdenadas.length){
              return Padding(
                padding: EdgeInsets.only(
                  top: tareasOrdenadas.isEmpty ? 0 : 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tareas grupales',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              );
            }
            if(index > tareasOrdenadas.length){
              final grupal = grupales[index - tareasOrdenadas.length - 1];
              final grupo = resumen!.grupoDe(grupal)!;
              return Padding(
                key: ValueKey(grupal.clave),
                padding: const EdgeInsets.only(bottom: 12),
                child: TareaGrupalMini(
                  tarea: grupal,
                  grupo: grupo,
                  colorAsignatura: _colores[grupal.asignatura],
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => TareaGrupalScreen(
                        tarea: grupal,
                        grupo: grupo,
                        repositorio: _repositorio,
                        colorAsignatura: _colores[grupal.asignatura],
                      ),
                    ),
                  ),
                ),
              );
            }
            final tarea = tareasOrdenadas[index];
            return Padding(
              key: ValueKey(tarea.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: TareaMini(
                titulo: tarea.titulo,
                asignatura: tarea.asignatura,
                repositorio: _repositorio,
                fechaLimite: fechaTarea(tarea.fechaLimite, corta: true),
                tipo: tarea.tipo,
                completada: tarea.estado == EstadoTarea.completada,
                totalSubtareas: tarea.subtareas.length,
                subtareasCompletadas: tarea.subtareasCompletadas,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TareaScreen(tarea: tarea, repositorio: _repositorio),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
