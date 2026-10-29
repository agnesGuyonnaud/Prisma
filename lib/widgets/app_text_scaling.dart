import 'package:flutter/widgets.dart';

const appTextScaleFactor = 1.15;

class AppTextScaleScope extends InheritedWidget {
  const AppTextScaleScope({
    super.key,
    required this.systemTextScaler,
    required super.child,
  });

  final TextScaler systemTextScaler;

  static TextScaler systemTextScalerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppTextScaleScope>();
    return scope?.systemTextScaler ?? MediaQuery.textScalerOf(context);
  }

  @override
  bool updateShouldNotify(AppTextScaleScope oldWidget) =>
      systemTextScaler != oldWidget.systemTextScaler;
}

class AppTextScaler extends TextScaler {
  const AppTextScaler(this.systemTextScaler, this.factor);

  final TextScaler systemTextScaler;
  final double factor;

  @override
  double get textScaleFactor => scale(1);

  @override
  double scale(double fontSize) => systemTextScaler.scale(fontSize) * factor;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.systemTextScaler == systemTextScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(systemTextScaler, factor);
}
