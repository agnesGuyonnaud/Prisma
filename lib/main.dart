import 'package:flutter/material.dart';

import 'screens/home.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Genera superficies, colores de texto y estados coherentes con Material 3.
      // La paleta parte del morado de referencia; no depende del fondo del móvil.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4834B6)),
      ),
      home: const HomeScreen(),
    );
  }
}
