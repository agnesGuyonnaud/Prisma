import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Auth{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;
  static Future<void>? _inicializacionGoogle;
  static bool _googleListo = false;

  final String _webClientId =
      "384332875358-o3ls3dqd2hvtontjsfsat04s1u69p2c5.apps.googleusercontent.com";

  /// Input:
  /// - No recibe parámetros; observa los cambios de usuario de Firebase.
  /// Output:
  /// - `Stream<User?>`: flujo de usuarios autenticados o `null` al cerrar sesión.
  /// Resumen:
  /// - Expone los cambios de autenticación como un flujo.
  Stream<User?> get usuario => _auth.userChanges();

  /// Input:
  /// - No recibe parámetros; utiliza el identificador de cliente web configurado.
  /// Output:
  /// - `Future<void>`: termina cuando Google Sign-In queda inicializado.
  /// Resumen:
  /// - Inicializa Google Sign-In una sola vez y permite reintentar si falla.
  Future<void> inicializarGoogle() async{
    if(_googleListo) return;
    final inicializacion = _inicializacionGoogle ??= _google.initialize(
      serverClientId: _webClientId,
    );
    try{
      await inicializacion;
      _googleListo = true;
    }catch(_){
      if(identical(_inicializacionGoogle, inicializacion)){
        _inicializacionGoogle = null;
      }
      rethrow;
    }
  }

  /// Input:
  /// - `nombre` (`String`): nombre visible de la nueva cuenta.
  /// - `correo` (`String`): correo usado para crear la cuenta.
  /// - `clave` (`String`): contraseña de la nueva cuenta.
  /// Output:
  /// - `Future<String?>`: `null` si se registró o un mensaje si hubo error.
  /// Resumen:
  /// - Crea la cuenta con Firebase y asigna el nombre visible.
  Future<String?> registrar(String nombre, String correo, String clave) async{
    try{
      final res = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      );
      await res.user?.updateDisplayName(nombre.trim());
      return null;
    }on FirebaseAuthException catch(e){
      return _mensajeError(e.code);
    }
  }

  /// Input:
  /// - `correo` (`String`): correo de la cuenta.
  /// - `clave` (`String`): contraseña de la cuenta.
  /// Output:
  /// - `Future<String?>`: `null` si inició sesión o un mensaje si hubo error.
  /// Resumen:
  /// - Autentica la cuenta con correo y contraseña mediante Firebase.
  Future<String?> iniciarSesion(String correo, String clave) async{
    try{
      await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      );
      return null;
    }on FirebaseAuthException catch(e){
      return _mensajeError(e.code);
    }
  }

  /// Input:
  /// - No recibe parámetros; inicia el flujo de autenticación de Google.
  /// Output:
  /// - `Future<String?>`: `null` si tuvo éxito o se canceló, mensaje si falló.
  /// Resumen:
  /// - Autentica con Google y entrega la credencial a Firebase.
  Future<String?> iniciarConGoogle() async{
    try{
      await inicializarGoogle();
      final cuenta = await _google.authenticate();
      final credencial = GoogleAuthProvider.credential(
        idToken: cuenta.authentication.idToken,
      );
      await _auth.signInWithCredential(credencial);
      return null;
    }on GoogleSignInException catch(e){
      if(e.code == GoogleSignInExceptionCode.canceled) return null;
      return "No se pudo iniciar sesión con Google";
    }on FirebaseAuthException catch(e){
      return _mensajeError(e.code);
    }
  }

  /// Input:
  /// - `correo` (`String`): dirección que recibirá el enlace de recuperación.
  /// Output:
  /// - `Future<String?>`: `null` si se envió o un mensaje si hubo error.
  /// Resumen:
  /// - Solicita a Firebase el restablecimiento de contraseña en español.
  Future<String?> recuperarContrasena(String correo) async{
    try{
      await _auth.setLanguageCode("es");
      await _auth.sendPasswordResetEmail(email: correo.trim());
      return null;
    }on FirebaseAuthException catch(e){
      return _mensajeError(e.code);
    }
  }

  /// Input:
  /// - No recibe parámetros; usa las sesiones activas de Google y Firebase.
  /// Output:
  /// - `Future<void>`: termina cuando se cierran las sesiones.
  /// Resumen:
  /// - Cierra Google Sign-In si se inicializó y luego cierra Firebase.
  Future<void> cerrarSesion() async{
    if(_googleListo) await _google.signOut();
    await _auth.signOut();
  }

  /// Input:
  /// - `codigo` (`String`): código de error devuelto por Firebase.
  /// Output:
  /// - `String`: mensaje localizado y entendible para el usuario.
  /// Resumen:
  /// - Traduce códigos de autenticación a mensajes en español.
  String _mensajeError(String codigo){
    switch(codigo){
      case "invalid-email":
        return "El correo no es válido";
      case "email-already-in-use":
        return "Ya existe una cuenta con este correo";
      case "weak-password":
        return "La contraseña debe tener al menos 6 caracteres";
      case "invalid-credential":
        return "Correo o contraseña incorrectos";
      case "user-disabled":
        return "Esta cuenta está deshabilitada";
      case "operation-not-allowed":
        return "Este método de acceso no está habilitado";
      case "too-many-requests":
        return "Demasiados intentos, espera un momento";
      case "network-request-failed":
        return "Fallo con la conexión a internet";
      default:
        return "Ocurrió un error, inténtalo de nuevo";
    }
  }
}
