import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/tareas_repository.dart';
import 'screens/home.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.repositorio});

  final TareasRepository? repositorio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Traduce también los calendarios, selectores de hora y controles nativos.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Genera superficies, colores de texto y estados coherentes con Material 3.
      // La paleta parte del morado de referencia; no depende del fondo del móvil.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4834B6)),
      ),
      home: HomeScreen(repositorio: repositorio),
    );
  }
}
