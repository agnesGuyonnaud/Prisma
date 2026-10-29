import 'package:flutter/widgets.dart';

const appTextScaleFactor = 1.15;

class AppTextScaleScope extends InheritedWidget {
  const AppTextScaleScope({
    super.key,
    required this.systemTextScaler,
    required super.child,
  });

  final TextScaler systemTextScaler;

  /// Input:
  /// - `context` (`BuildContext`): contexto donde se busca el scope.
  /// Output:
  /// - `TextScaler`: escala de sistema original, o la escala del MediaQuery.
  /// Resumen:
  /// - Recupera la escala de accesibilidad del sistema sin el aumento de la app.
  static TextScaler systemTextScalerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppTextScaleScope>();
    return scope?.systemTextScaler ?? MediaQuery.textScalerOf(context);
  }

  /// Input:
  /// - `oldWidget` (`AppTextScaleScope`): scope anterior del árbol.
  /// Output:
  /// - `bool`: indica si cambió el escalador de texto.
  /// Resumen:
  /// - Notifica a los descendientes cuando cambia la escala del sistema.
  @override
  bool updateShouldNotify(AppTextScaleScope oldWidget) =>
      systemTextScaler != oldWidget.systemTextScaler;
}

class AppTextScaler extends TextScaler {
  const AppTextScaler(this.systemTextScaler, this.factor);

  final TextScaler systemTextScaler;
  final double factor;

  /// Input:
  /// - No recibe parámetros; evalúa la escala combinada para un punto.
  /// Output:
  /// - `double`: factor de escala resultante para texto.
  /// Resumen:
  /// - Expone el factor compatible con la API anterior de `TextScaler`.
  @override
  double get textScaleFactor => scale(1);

  /// Input:
  /// - `fontSize` (`double`): tamaño de fuente original en píxeles lógicos.
  /// Output:
  /// - `double`: tamaño tras aplicar escala del sistema y aumento de la app.
  /// Resumen:
  /// - Conserva la accesibilidad del dispositivo y aumenta proporcionalmente el texto.
  @override
  double scale(double fontSize) => systemTextScaler.scale(fontSize) * factor;

  /// Input:
  /// - `other` (`Object`): objeto con el que se compara este escalador.
  /// Output:
  /// - `bool`: `true` si ambos escaladores tienen la misma configuración.
  /// Resumen:
  /// - Compara la escala del sistema y el factor adicional.
  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.systemTextScaler == systemTextScaler &&
      other.factor == factor;

  /// Input:
  /// - No recibe parámetros; usa la configuración de este escalador.
  /// Output:
  /// - `int`: hash coherente con la igualdad de los escaladores.
  /// Resumen:
  /// - Genera el valor hash a partir del escalador del sistema y el factor.
  @override
  int get hashCode => Object.hash(systemTextScaler, factor);
}
