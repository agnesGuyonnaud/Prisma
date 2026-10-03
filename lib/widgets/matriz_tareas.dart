import 'package:flutter/material.dart';

import '../models/tarea_model.dart';
import '../widgets/tarea_list.dart';

class MatrizTareas extends StatelessWidget {
  const MatrizTareas({super.key, required this.tareas});

  final List<Tarea> tareas;

  static const _cadranes = [
    _Cadran(
      titulo: 'Importante y urgente',
      descripcion: 'Hacer ahora',
      importante: true,
      urgente: true,
      color: Color(0xFFF3C5B8),
    ),
    _Cadran(
      titulo: 'Importante, no urgente',
      descripcion: 'Planificar',
      importante: true,
      urgente: false,
      color: Color(0xFFD7E8BD),
    ),
    _Cadran(
      titulo: 'No importante, urgente',
      descripcion: 'Delegar',
      importante: false,
      urgente: true,
      color: Color(0xFFF4E0A5),
    ),
    _Cadran(
      titulo: 'No importante, no urgente',
      descripcion: 'Reducir o eliminar',
      importante: false,
      urgente: false,
      color: Color(0xFFD6E6EA),
    ),
  ];

  List<Tarea> _tareasDelCadran(_Cadran cadran) => tareas.where((tarea) {
    final importante = tarea.importancia >= 3;
    return importante == cadran.importante &&
        tarea.isUrgente() == cadran.urgente;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _cadranes.length,
      itemBuilder: (context, index) {
        final cadran = _cadranes[index];
        final tareasCadran = _tareasDelCadran(cadran);
        return Card.filled(
          margin: EdgeInsets.zero,
          color: cadran.color,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    _ListaCadranScreen(cadran: cadran, tareas: tareasCadran),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        cadran.titulo,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Text(
                    cadran.descripcion,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${tareasCadran.length} tareas'),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
/* 
class MatrizTareasScreen extends StatelessWidget {
  const MatrizTareasScreen({super.key, required this.tareas});

  final List<Tarea> tareas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matriz de tareas'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MatrizTareas(tareas: tareas),
    );
  }
} */

class _ListaCadranScreen extends StatelessWidget {
  const _ListaCadranScreen({required this.cadran, required this.tareas});

  final _Cadran cadran;
  final List<Tarea> tareas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cadran.titulo),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: tareas.isEmpty
          ? const Center(child: Text('No hay tareas en este cuadrante.'))
          : TareaList(tareasOrdenadas: tareas),

      /* final now = DateTime.now();
                    final tareasOrdenadas = [...tareas]
                      ..sort(
                        (a, b) => b
                            .getImportanceEmergencyScore(now)
                            .compareTo(a.getImportanceEmergencyScore(now)),
                      );
                    return TareaList(
                      tareasOrdenadas: tareasOrdenadas,
                      repositorio: _repositorio,
                    ); */
    );
  }
}

class _Cadran {
  const _Cadran({
    required this.titulo,
    required this.descripcion,
    required this.importante,
    required this.urgente,
    required this.color,
  });

  final String titulo;
  final String descripcion;
  final bool importante;
  final bool urgente;
  final Color color;
}
