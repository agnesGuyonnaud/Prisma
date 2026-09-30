import 'package:flutter/material.dart';

import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import '../widgets/tarea_mini.dart';
import '../screens/tarea.dart';
import '../data/tareas_repository.dart';

/// Selector compartido por el formulario y el detalle. Solo admite enteros.
/// Quien lo utiliza decide cuándo guardar el cambio en SQLite.
class TareaList extends StatelessWidget {
  List<Tarea> tareasOrdenadas;
  late final TareasRepository _repositorio;

  TareaList({
    super.key,
    required this.tareasOrdenadas,
    required this._repositorio,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Permite desplazar la última tarjeta por encima del FAB.
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TareaScreen(tarea: tarea, repositorio: _repositorio),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
