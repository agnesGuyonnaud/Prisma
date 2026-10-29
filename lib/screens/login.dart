import 'package:flutter/material.dart';

import '../data/auth.dart';
import '../widgets/app_text_scaling.dart';

class LoginScreen extends StatefulWidget{
  const LoginScreen({super.key, this.auth});

  final Auth? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>{
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  late final Auth _auth;
  bool _registrando = false;
  bool _cargando = false;
  bool _claveOculta = true;

  @override
  void initState(){
    super.initState();
    _auth = widget.auth ?? Auth();
  }

  @override
  void dispose(){
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  /// Input:
  /// - `accion` (`Future<String?> Function()`): operación de autenticación.
  /// Output:
  /// - `Future<void>`: termina al completar la operación y actualizar la carga.
  /// Resumen:
  /// - Ejecuta una acción de autenticación y presenta el error que devuelva.
  Future<void> _ejecutar(Future<String?> Function() accion) async{
    setState(() => _cargando = true);
    try{
      final error = await accion();
      if(error != null && mounted) _mostrar(error);
    }catch(_){
      if(mounted) _mostrar("Ocurrió un error, inténtalo de nuevo");
    }finally{
      if(mounted) setState(() => _cargando = false);
    }
  }

  /// Input:
  /// - No recibe parámetros; usa el formulario y modo actual.
  /// Output:
  /// - `Future<void>`: termina al validar y ejecutar el acceso o registro.
  /// Resumen:
  /// - Valida los campos y llama al flujo de autenticación correspondiente.
  Future<void> _continuar() async{
    if(!_formulario.currentState!.validate()) return;
    await _ejecutar(
      () => _registrando
          ? _auth.registrar(_nombre.text, _correo.text, _clave.text)
          : _auth.iniciarSesion(_correo.text, _clave.text),
    );
  }

  /// Input:
  /// - No recibe parámetros; usa el correo escrito en el formulario.
  /// Output:
  /// - `Future<void>`: termina tras solicitar el restablecimiento.
  /// Resumen:
  /// - Valida el correo y solicita el envío del enlace de recuperación.
  Future<void> _recuperar() async{
    if(_validarCorreo(_correo.text) != null){
      _mostrar("Escribe tu correo para recuperar la contraseña");
      return;
    }
    await _ejecutar(() async{
      final error = await _auth.recuperarContrasena(_correo.text);
      return error ?? "Si el correo está registrado, te enviamos un enlace";
    });
  }

  /// Input:
  /// - `mensaje` (`String`): texto que se mostrará en pantalla.
  /// Output:
  /// - `void`: presenta una notificación temporal.
  /// Resumen:
  /// - Muestra mensajes de autenticación al usuario.
  void _mostrar(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
      );
  }

  /// Input:
  /// - No recibe parámetros; alterna entre acceso y registro.
  /// Output:
  /// - `void`: actualiza el modo y reinicia la validación del formulario.
  /// Resumen:
  /// - Cambia entre inicio de sesión y creación de cuenta.
  void _cambiarModo(){
    setState((){
      _registrando = !_registrando;
      _formulario.currentState?.reset();
    });
  }

  /// Input:
  /// - `valor` (`String?`): correo ingresado, posiblemente vacío.
  /// Output:
  /// - `String?`: mensaje de validación o `null` si el correo es válido.
  /// Resumen:
  /// - Comprueba que se haya ingresado un correo con formato aceptado.
  String? _validarCorreo(String? valor){
    final correo = valor?.trim() ?? "";
    if(correo.isEmpty) return "Ingresa tu correo";
    if(!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(correo)){
      return "El correo no es válido";
    }
    return null;
  }

  /// Input:
  /// - `valor` (`String?`): contraseña ingresada.
  /// Output:
  /// - `String?`: mensaje de validación o `null` si cumple las reglas.
  /// Resumen:
  /// - Comprueba que la clave no esté vacía y cumpla el mínimo de registro.
  String? _validarClave(String? valor){
    if(valor == null || valor.isEmpty) return "Ingresa tu contraseña";
    if(_registrando && valor.length < 6){
      return "Debe tener al menos 6 caracteres";
    }
    return null;
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema, formulario y acciones.
  /// Output:
  /// - `Widget`: devuelve la pantalla de acceso o registro.
  /// Resumen:
  /// - Construye el formulario de autenticación y sus opciones asociadas.
  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: AppTextScaleScope.systemTextScalerOf(context),
      ),
      child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _formulario,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Image.asset(
                      "assets/images/logo.png",
                      height: 160,
                      semanticLabel: "PomoGrid",
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _registrando ? "Crea una cuenta" : "Inicia sesión",
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if(_registrando) ...[
                      TextFormField(
                        controller: _nombre,
                        enabled: !_cargando,
                        decoration: const InputDecoration(
                          labelText: "Nombre",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (valor) => (valor?.trim().isEmpty ?? true)
                            ? "Ingresa tu nombre"
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _correo,
                      enabled: !_cargando,
                      decoration: const InputDecoration(
                        labelText: "Correo",
                        hintText: "usuario@ejemplo.com",
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      validator: _validarCorreo,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clave,
                      enabled: !_cargando,
                      obscureText: _claveOculta,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        helperText: _registrando ? "Mínimo 6 caracteres" : null,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _claveOculta
                              ? "Mostrar contraseña"
                              : "Ocultar contraseña",
                          icon: Icon(
                            _claveOculta
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _claveOculta = !_claveOculta),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _registrando
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => _cargando ? null : _continuar(),
                      validator: _validarClave,
                    ),
                    if(!_registrando)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _cargando ? null : _recuperar,
                          child: const Text("¿Olvidaste tu contraseña?"),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _cargando ? null : _continuar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _cargando
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registrando ? "Crear cuenta" : "Iniciar sesión"),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "o",
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _cargando
                          ? null
                          : () => _ejecutar(_auth.iniciarConGoogle),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: Image.asset(
                        "assets/images/google.webp",
                        height: 18,
                      ),
                      label: const Text("Continuar con Google"),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _cargando ? null : _cambiarModo,
                      child: Text(
                        _registrando
                            ? "¿Ya tienes cuenta? Inicia sesión"
                            : "¿No tienes cuenta? Crea una",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
