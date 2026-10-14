import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Auth {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final GoogleSignIn google = GoogleSignIn.instance;
  bool googleListo = false;

  final String webClientId =
      '384332875358-o3ls3dqd2hvtontjsfsat04s1u69p2c5.apps.googleusercontent.com';

  Stream<User?> get usuario => auth.userChanges();

  Future<String?> registrar(String nombre, String correo, String clave) async{
    try {
      final res = await auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      );
      await res.user?.updateDisplayName(nombre.trim());
      return null;
    } on FirebaseAuthException catch (e){
      return mensajeError(e.code);
    }
  }

  Future<String?> iniciarSesion(String correo, String clave) async{
    try {
      await auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      );
      return null;
    } on FirebaseAuthException catch (e){
      return mensajeError(e.code);
    }
  }

  Future<String?> iniciarConGoogle() async{
    try {
      if (!googleListo){
        await google.initialize(serverClientId: webClientId);
        googleListo = true;
      }
      final cuenta = await google.authenticate();
      final credencial = GoogleAuthProvider.credential(
        idToken: cuenta.authentication.idToken,
      );
      await auth.signInWithCredential(credencial);
      return null;
    } on GoogleSignInException catch (e){
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return "No se pudo iniciar sesión con Google";
    } on FirebaseAuthException catch (e){
      return mensajeError(e.code);
    }
  }

  Future<String?> recuperarContrasena(String correo) async{
    try {
      await auth.setLanguageCode('es');
      await auth.sendPasswordResetEmail(email: correo.trim());
      return null;
    } on FirebaseAuthException catch (e){
      return mensajeError(e.code);
    }
  }

  Future<void> cerrarSesion() async{
    if (googleListo) await google.signOut();
    await auth.signOut();
  }

  String mensajeError(String codigo){
    switch (codigo){
      case "invalid-email":
        return "El correo no es válido";
      case "email-already-in-use":
        return "Ya existe una cuenta con este correo";
      case "weak-password":
        return "La contraseña debe tener al menos 6 caracteres";
      case "invalid-credential":
        return "Correo o contraseña incorrectos";
      case "too-many-requests":
        return "Demasiados intentos, espera un momento";
      case "network-request-failed":
        return "Fallo con la conexión a internet";
      default:
        return "Ocurrió un error, inténtalo de nuevo";
    }
  }
}
