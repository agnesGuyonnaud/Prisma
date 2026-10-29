import 'package:flutter/material.dart';

const rutaInicio = '/inicio';
const rutaMatriz = '/matriz';
const rutaPomodoro = '/pomodoro';

/// Input:
/// - `context` (`BuildContext`): contexto desde el que se navega.
/// - `builder` (`WidgetBuilder`): constructor de la pantalla de Inicio.
/// Output:
/// - `Future<void>`: termina cuando se retira la ruta abierta.
/// Resumen:
/// - Añade Inicio a la pila sin reemplazar las pantallas anteriores.
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

/// Input:
/// - `context` (`BuildContext`): contexto desde el que se navega.
/// - `ruta` (`String`): nombre de la ruta principal que se abrirá.
/// - `builder` (`WidgetBuilder`): constructor si la ruta no está en la pila.
/// Output:
/// - `Future<void>`: termina cuando se completa la navegación.
/// Resumen:
/// - Vuelve a una ruta existente o la agrega si todavía no está en la pila.
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
