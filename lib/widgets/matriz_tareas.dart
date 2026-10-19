import 'package:flutter/material.dart';

import '../models/cadran.dart';
import '../models/tarea_model.dart';
import '../widgets/tarea_list.dart';

class MatrizTareas extends StatelessWidget {
  const MatrizTareas({super.key, required this.tareas});

  final List<Tarea> tareas;

  List<Tarea> _tareasDelCadran(Cadran cadran) => tareas.where((tarea){
    final importante = tarea.importancia >= 3;
    return importante == cadran.importante &&
        tarea.isUrgente() == cadran.urgente;
  }).toList();

  @override
  Widget build(BuildContext context){
    final colores = Theme.of(context).colorScheme;
    final cadranes = [
      Cadran(
        titulo: 'Importante y urgente',
        descripcion: 'Hacer ahora',
        importante: true,
        urgente: true,
        color: const Color(0xFFBAE147),
      ),
      Cadran(
        titulo: 'Importante, no urgente',
        descripcion: 'Planificar',
        importante: true,
        urgente: false,
        color: Color.lerp(colores.primaryContainer, colores.primary, 0.4)!,
      ),
      Cadran(
        titulo: 'No importante, urgente',
        descripcion: 'Delegar',
        importante: false,
        urgente: true,
        color: colores.tertiaryContainer,
      ),
      Cadran(
        titulo: 'No importante, no urgente',
        descripcion: 'Reducir o eliminar',
        importante: false,
        urgente: false,
        color: colores.primaryContainer,
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: cadranes.length,
      itemBuilder: (context, index){
        final cadran = cadranes[index];
        final tareasCadran = _tareasDelCadran(cadran);
        return Card.filled(
          margin: EdgeInsets.zero,
          color: cadran.color,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => _ListaCadranScreen(cadran: cadran),
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

class _ListaCadranScreen extends StatelessWidget {
  const _ListaCadranScreen({required this.cadran});

  final Cadran cadran;

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(cadran.titulo),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TareaList(cadran: cadran),
      ),
    );
  }
}
