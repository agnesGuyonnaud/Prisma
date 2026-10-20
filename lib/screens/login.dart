import 'package:flutter/material.dart';

import '../data/auth.dart';

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

  Future<void> _continuar() async{
    if(!_formulario.currentState!.validate()) return;
    await _ejecutar(
      () => _registrando
          ? _auth.registrar(_nombre.text, _correo.text, _clave.text)
          : _auth.iniciarSesion(_correo.text, _clave.text),
    );
  }

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

  void _mostrar(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
      );
  }

  void _cambiarModo(){
    setState((){
      _registrando = !_registrando;
      _formulario.currentState?.reset();
    });
  }

  String? _validarCorreo(String? valor){
    final correo = valor?.trim() ?? "";
    if(correo.isEmpty) return "Ingresa tu correo";
    if(!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(correo)){
      return "El correo no es válido";
    }
    return null;
  }

  String? _validarClave(String? valor){
    if(valor == null || valor.isEmpty) return "Ingresa tu contraseña";
    if(_registrando && valor.length < 6){
      return "Debe tener al menos 6 caracteres";
    }
    return null;
  }

  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    return Scaffold(
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
    );
  }
}
