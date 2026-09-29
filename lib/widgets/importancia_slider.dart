import 'package:flutter/material.dart';

/// Selector compartido por el formulario y el detalle. Solo admite enteros.
/// Quien lo utiliza decide cuándo guardar el cambio en SQLite.
class ImportanciaSlider extends StatelessWidget {
  const ImportanciaSlider({
    super.key,
    required this.valor,
    required this.onChanged,
    this.onChangeEnd,
  });

  final int valor;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Importancia', style: tema.textTheme.titleSmall),
            ),
            Text('$valor / 5', style: tema.textTheme.titleSmall),
          ],
        ),
        Semantics(
          label: 'Importancia',
          child: Slider(
            value: valor.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$valor',
            semanticFormatterCallback: (valor) => '${valor.round()} de 5',
            onChanged: onChanged == null
                ? null
                : (valor) => onChanged!(valor.round()),
            onChangeEnd: onChangeEnd == null
                ? null
                : (valor) => onChangeEnd!(valor.round()),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '1 · Menos importante',
                style: tema.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '5 · Más importante',
                textAlign: TextAlign.end,
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
