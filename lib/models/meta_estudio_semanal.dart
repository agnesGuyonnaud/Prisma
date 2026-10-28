import 'asignatura_model.dart';

class MetaEstudioSemanal {
  const MetaEstudioSemanal({
    required this.asignatura,
    required this.segundosMeta,
    required this.segundosEstudiados,
  });

  final Asignatura asignatura;
  final int? segundosMeta;
  final int segundosEstudiados;

  double get progreso {
    final meta = segundosMeta;
    if (meta == null || meta <= 0) return 0;
    return (segundosEstudiados / meta).clamp(0.0, 1.0).toDouble();
  }

  int get porcentaje => (progreso * 100).round();
}
