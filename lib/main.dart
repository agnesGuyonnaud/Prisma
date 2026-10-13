import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth.dart';
import 'data/tareas_repository.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'widgets/tarea_list.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized(); //con esto se conecta a la firebase y espera a que este listo para continuar con el inicio de la app 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
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
      navigatorObservers: [tareasRouteObserver],
      // Genera superficies, colores de texto y estados coherentes con Material 3.
      // La paleta parte del morado de referencia; no depende del fondo del móvil.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6674E8),
          primary: const Color(0xFF6674E8),
          secondary: const Color(0xFFBAE147),
        ),
      ),
      //la sesion es distinta si el usuario esta o no logeado
      //si no lo esta, inicia con la pantalla de login, si lo esta, con la de home
      home: StreamBuilder<User?>(
        stream: Auth().usuario,
        builder: (context, snapshot){
          if (snapshot.connectionState == ConnectionState.waiting){
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ==null
              ?const LoginScreen()
              :HomeScreen(repositorio: repositorio);
        },
      ),
    );
  }
}
