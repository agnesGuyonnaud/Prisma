import 'package:flutter/material.dart';

const rutaInicio = '/inicio';
const rutaMatriz = '/matriz';
const rutaPomodoro = '/pomodoro';

Future<void> abrirInicioConservandoPila(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: rutaInicio),
      builder: builder,
    ),
  );
}

Future<void> navegarAPantallaPrincipal(
  BuildContext context, {
  required String ruta,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context);
  var rutaEncontrada = false;

  navigator.popUntil((actual) {
    if (actual.settings.name == ruta) {
      rutaEncontrada = true;
      return true;
    }
    return actual.isFirst;
  });

  if (!rutaEncontrada) {
    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: ruta),
        builder: builder,
      ),
    );
  }
}
