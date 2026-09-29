/// Fecha local en español, compartida por el formulario, el home y el detalle.
String fechaTarea(DateTime fecha, {bool corta = false}) {
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
