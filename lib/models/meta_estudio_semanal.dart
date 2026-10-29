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

  /// Input:
  /// - No recibe parámetros; utiliza el tiempo registrado y la meta semanal.
  /// Output:
  /// - `double`: progreso entre `0.0` y `1.0`.
  /// Resumen:
  /// - Calcula la proporción de la meta completada, limitada al 100 %.
  double get progreso {
    final meta = segundosMeta;
    if (meta == null || meta <= 0) return 0;
    return (segundosEstudiados / meta).clamp(0.0, 1.0).toDouble();
  }

  /// Input:
  /// - No recibe parámetros; deriva el porcentaje del progreso calculado.
  /// Output:
  /// - `int`: porcentaje entero entre 0 y 100.
  /// Resumen:
  /// - Presenta el progreso como porcentaje redondeado.
  int get porcentaje => (progreso * 100).round();
}
