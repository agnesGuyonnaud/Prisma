import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth.dart';
import 'data/pomodoro_notifications.dart';
import 'data/tareas_repository.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'widgets/app_text_scaling.dart';
import 'widgets/tarea_list.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificacionesLocalesPomodoro.instancia.cancelar();
  } catch (error) {
    debugPrint('No se pudieron limpiar avisos Pomodoro anteriores: $error');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget{
  const MainApp({super.key, this.repositorio});

  final TareasRepository? repositorio;

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return AppTextScaleScope(
          systemTextScaler: mediaQuery.textScaler,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: AppTextScaler(
                mediaQuery.textScaler,
                appTextScaleFactor,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },

      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorObservers: [tareasRouteObserver],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6674E8),
          primary: const Color(0xFF4833B4),
          onPrimary: Colors.white,
          secondary: const Color(0xFFBAE147),
          onSecondary: Colors.black,
          tertiary: const Color(0xFF6674E8),
          onTertiary: Colors.white,
        ),
      ),

      home: StreamBuilder<User?>(
        stream: Auth().usuario,
        builder: (context, snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == null
              ? const LoginScreen()
              : HomeScreen(repositorio: repositorio);
        },
      ),
    );
  }
}
