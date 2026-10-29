/// Input:
/// - `fecha` (`DateTime`): fecha y hora que se mostrarán.
/// - `corta` (`bool`): usa el nombre abreviado del mes cuando es `true`.
/// Output:
/// - `String`: fecha localizada con la hora en formato de 24 horas.
/// Resumen:
/// - Formatea una fecha límite para mostrarla en sus variantes larga o corta.
String fechaTarea(DateTime fecha, {bool corta = false}){
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final mes = meses[fecha.month - 1];
  final hora =
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  return corta
      ? '${fecha.day} ${mes.substring(0, 3)} ${fecha.year} · $hora'
      : '${fecha.day} de $mes de ${fecha.year} · $hora';
}
