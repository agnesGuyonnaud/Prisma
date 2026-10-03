import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import 'tarea_mini.dart';
import '../screens/tarea.dart';

final RouteObserver<ModalRoute<dynamic>> tareasRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class TareaList extends StatefulWidget {
  const TareaList({super.key, this.repositorio, this.tareasOrdenadas})
    : assert(repositorio != null || tareasOrdenadas != null);

  final TareasRepository? repositorio;
  final List<Tarea>? tareasOrdenadas;

  @override
  State<TareaList> createState() => _TareaListState();
}

class _TareaListState extends State<TareaList> with RouteAware {
  late Future<List<Tarea>> _tareas;
  ModalRoute<dynamic>? _ruta;

  @override
  void initState() {
    super.initState();
    _tareas =
        widget.repositorio?.listar() ?? Future.value(widget.tareasOrdenadas!);
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
  void didPopNext() {
    if (widget.repositorio != null) _recargar();
  }

  @override
  void dispose() {
    tareasRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _recargar() {
    final repositorio = widget.repositorio;
    if (!mounted || repositorio == null) return;
    setState(() => _tareas = repositorio.listar());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tarea>>(
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
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: tareasOrdenadas.length,
          itemBuilder: (context, index) {
            final tarea = tareasOrdenadas[index];
            return Padding(
              key: ValueKey(tarea.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: TareaMini(
                titulo: tarea.titulo,
                asignatura: tarea.asignatura,
                fechaLimite: fechaTarea(tarea.fechaLimite, corta: true),
                tipo: tarea.tipo,
                completada: tarea.estado == EstadoTarea.completada,
                totalSubtareas: tarea.subtareas.length,
                subtareasCompletadas: tarea.subtareasCompletadas,
                onTap: widget.repositorio == null
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => TareaScreen(
                            tarea: tarea,
                            repositorio: widget.repositorio!,
                          ),
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
