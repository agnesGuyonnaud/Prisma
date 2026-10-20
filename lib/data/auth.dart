import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Auth{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;
  static Future<void>? _inicializacionGoogle;
  static bool _googleListo = false;

  final String _webClientId =
      "384332875358-o3ls3dqd2hvtontjsfsat04s1u69p2c5.apps.googleusercontent.com";

  Stream<User?> get usuario => _auth.userChanges();

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

  Future<String?> recuperarContrasena(String correo) async{
    try{
      await _auth.setLanguageCode("es");
      await _auth.sendPasswordResetEmail(email: correo.trim());
      return null;
    }on FirebaseAuthException catch(e){
      return _mensajeError(e.code);
    }
  }

  Future<void> cerrarSesion() async{
    if(_googleListo) await _google.signOut();
    await _auth.signOut();
  }

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
