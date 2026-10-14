import 'package:flutter/material.dart';

import '../data/auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  final Auth? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    final error = await accion();
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) _mostrar(error);
  }

  Future<void> _continuar() async{
    if (!_formulario.currentState!.validate()) return;
    await _ejecutar(
      () => _registrando
          ? _auth.registrar(_nombre.text, _correo.text, _clave.text)
          : _auth.iniciarSesion(_correo.text, _clave.text),
    );
  }

  Future<void> _recuperar() async{
    final error = _validarCorreo(_correo.text);
    if (error != null){
      _mostrar("Escribe tu correo para recuperar la contraseña");
      return;
    }
    setState(() => _cargando = true);
    final resultado = await _auth.recuperarContrasena(_correo.text);
    if (!mounted) return;
    setState(() => _cargando = false);
    _mostrar(
      resultado ?? "Si el correo está registrado, te enviamos un enlace",
    );
  }

  void _mostrar(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String? _validarCorreo(String? valor){
    final correo = valor?.trim() ?? "";
    if (correo.isEmpty) return "Ingresa tu correo";
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(correo)){
      return "El correo no es válido";
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
            child: Form(
              key: _formulario,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    "Prisma",
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    _registrando ? "Crea una cuenta" : "Inicia sesión",
                    textAlign: TextAlign.center,
                    style: tema.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_registrando) ...[
                    TextFormField(
                      controller: _nombre,
                      enabled: !_cargando,
                      decoration: const InputDecoration(
                        labelText: "Nombre",
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
                    validator: (valor){
                      if (valor == null || valor.isEmpty){
                        return "Ingresa tu contraseña";
                      }

                      if (_registrando && valor.length < 6){
                        return "Debe tener al menos 6 caracteres";
                      }
                      return null;
                    },
                  ),
                  if (!_registrando)
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
                        : const Text("Continuar"),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('o'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _cargando
                        ? null
                        : () => _ejecutar(_auth.iniciarConGoogle),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text("Continuar con Google"),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => setState((){
                            _registrando = !_registrando;
                            _formulario.currentState?.reset();
                          }),
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
    );
  }
}
