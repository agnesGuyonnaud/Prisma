// StreamSubscription para escuchar los grupos en tiempo real.
import 'dart:async';

// Widgets de Material Design 3.
import 'package:flutter/material.dart';
// Clipboard para copiar el código del grupo.
import 'package:flutter/services.dart';

// Sincroniza las tareas grupales con Google Calendar.
import '../data/google_calendar_sync.dart';
// Grupos y tareas grupales en Firestore.
import '../data/grupos_repository.dart';
// Repositorio local (asignaturas y preferencias).
import '../data/tareas_repository.dart';
// Grupo, TareaGrupal y ResumenGrupos.
import '../models/grupo_model.dart';
// Navegación entre las pantallas principales.
import '../utils/navegacion_principal.dart';
// Tarjeta de tarea grupal e iniciales.
import '../widgets/tarea_grupal_mini.dart';
// Pantalla de Inicio.
import 'home.dart';
// Pantalla de Matriz.
import 'matriz.dart';
// Pantalla de Perfil.
import 'perfil.dart';
// Pantalla de Pomodoro.
import 'pomodoro.dart';
// Detalle de la tarea grupal.
import 'tarea_grupal.dart';
// Formulario para crear tareas grupales.
import 'tarea_grupal_formulario.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen({super.key, this.repositorio, this.grupos});

  final TareasRepository? repositorio;
  final GruposRepository? grupos;

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  late final TareasRepository _repositorio;
  late final GruposRepository _grupos;
  StreamSubscription<ResumenGrupos>? _suscripcion;
  ResumenGrupos? _resumen;
  bool _error = false;
  String? _filtro;
  Map<String, Color> _colores = {};
  bool _avisoCalendar = false;

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _grupos = widget.grupos ?? GruposRepository.instancia;
    _escuchar();
    _cargarColores();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  /// Input:
  /// - No recibe parámetros; usa el repositorio de grupos.
  /// Output:
  /// - `void`: inicia la suscripción.
  /// Resumen:
  /// - Escucha grupos y tareas en tiempo real, actualiza la pantalla y
  ///   sincroniza Calendar con cada cambio.
  void _escuchar() {
    _suscripcion?.cancel();
    _suscripcion = _grupos.resumen().listen(
      (resumen) {
        if (!mounted) return;
        setState(() {
          _resumen = resumen;
          _error = false;
          if (!resumen.grupos.any((g) => g.codigo == _filtro)) _filtro = null;
        });
        _sincronizarCalendar(resumen);
      },
      onError: (_) {
        if (mounted) setState(() => _error = true);
      },
    );
  }

  /// Input:
  /// - No recibe parámetros.
  /// Output:
  /// - `void`: reinicia la carga.
  /// Resumen:
  /// - Limpia el error y vuelve a escuchar los grupos.
  void _reintentar() {
    setState(() {
      _error = false;
      _resumen = null;
    });
    _escuchar();
  }

  /// Input:
  /// - No recibe parámetros; consulta las asignaturas locales.
  /// Output:
  /// - `Future<void>`: termina al guardar el mapa de colores.
  /// Resumen:
  /// - Asocia cada asignatura con su color para pintar las tarjetas.
  Future<void> _cargarColores() async {
    final asignaturas = await _repositorio.listarAsignaturas();
    if (!mounted) return;
    setState(() => _colores = {for (final a in asignaturas) a.nombre: a.color});
  }

  /// Input:
  /// - `resumen` (`ResumenGrupos`): tareas grupales actuales.
  /// Output:
  /// - `Future<void>`: termina al sincronizar o fallar.
  /// Resumen:
  /// - Sincroniza las tareas con Calendar y avisa una sola vez si falla.
  Future<void> _sincronizarCalendar(ResumenGrupos resumen) async {
    try {
      await GoogleCalendarSync(repositorio: _repositorio)
          .sincronizarTareasGrupalesSiHabilitada(resumen.tareas);
    } on GoogleCalendarSyncException catch (error) {
      if (!mounted || _avisoCalendar) return;
      _avisoCalendar = true;
      _mostrarMensaje(
        'Las tareas grupales no se sincronizaron con Calendar: ${error.message}',
      );
    }
  }

  /// Input:
  /// - `mensaje` (`String`): texto que se mostrará al usuario.
  /// Output:
  /// - `void`: muestra un aviso en la pantalla.
  /// Resumen:
  /// - Reemplaza el aviso actual por uno nuevo.
  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Input:
  /// - `error` (`Object`): error capturado.
  /// - `porDefecto` (`String`): mensaje para errores desconocidos.
  /// Output:
  /// - `String`: mensaje para el usuario.
  /// Resumen:
  /// - Usa el mensaje de las validaciones o uno genérico.
  String _textoError(Object error, String porDefecto) {
    if (error is ArgumentError) return error.message.toString();
    return porDefecto;
  }

  /// Input:
  /// - No recibe parámetros.
  /// Output:
  /// - `Future<void>`: termina al crear el grupo o cancelar.
  /// Resumen:
  /// - Pide el nombre, crea el grupo y muestra su código para compartirlo.
  Future<void> _crearGrupo() async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTexto(
        icono: Icons.group_add_outlined,
        titulo: 'Nuevo grupo',
        etiqueta: 'Nombre del grupo',
        ayuda: 'Por ejemplo: Proyecto de Apps Móviles',
        accion: 'Crear',
        largo: 60,
      ),
    );
    if (nombre == null || !mounted) return;
    try {
      final grupo = await _grupos.crearGrupo(nombre);
      if (!mounted) return;
      await _mostrarCodigo(grupo);
    } catch (error) {
      if (mounted) {
        _mostrarMensaje(_textoError(error, 'No se pudo crear el grupo.'));
      }
    }
  }

  /// Input:
  /// - No recibe parámetros.
  /// Output:
  /// - `Future<void>`: termina al unirse o cancelar.
  /// Resumen:
  /// - Pide el código y agrega al usuario al grupo correspondiente.
  Future<void> _unirseAGrupo() async {
    final codigo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTexto(
        icono: Icons.login,
        titulo: 'Unirme a un grupo',
        etiqueta: 'Código del grupo',
        ayuda: 'Pídele el código de 6 caracteres a un integrante.',
        accion: 'Unirme',
        largo: 6,
        mayusculas: true,
      ),
    );
    if (codigo == null || !mounted) return;
    try {
      final grupo = await _grupos.unirseAGrupo(codigo);
      if (mounted) _mostrarMensaje('Te uniste a ${grupo.nombre}.');
    } catch (error) {
      if (mounted) {
        _mostrarMensaje(_textoError(error, 'No se pudo unir al grupo.'));
      }
    }
  }

  /// Input:
  /// - `grupo` (`Grupo`): grupo que se abandonará.
  /// Output:
  /// - `Future<void>`: termina al salir o cancelar.
  /// Resumen:
  /// - Pide confirmación y quita al usuario del grupo.
  Future<void> _salirDeGrupo(Grupo grupo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: Text('¿Salir de ${grupo.nombre}?'),
        content: const Text(
          'Dejarás de ver sus tareas grupales. Puedes volver a unirte con el código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _grupos.salirDeGrupo(grupo);
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo salir del grupo.');
    }
  }

  /// Input:
  /// - `grupo` (`Grupo`): grupo cuyo código se copiará.
  /// Output:
  /// - `Future<void>`: termina al copiar.
  /// Resumen:
  /// - Copia el código al portapapeles y avisa al usuario.
  Future<void> _copiarCodigo(Grupo grupo) async {
    await Clipboard.setData(ClipboardData(text: grupo.codigo));
    if (mounted) _mostrarMensaje('Código ${grupo.codigo} copiado.');
  }

  /// Input:
  /// - `grupo` (`Grupo`): grupo recién creado.
  /// Output:
  /// - `Future<void>`: termina al cerrar el diálogo.
  /// Resumen:
  /// - Muestra el código del grupo con la opción de copiarlo.
  Future<void> _mostrarCodigo(Grupo grupo) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final tema = Theme.of(context);
        return AlertDialog(
          icon: const Icon(Icons.celebration_outlined),
          title: Text(grupo.nombre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Comparte este código con tus compañeros para que se unan:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                grupo.codigo,
                style: tema.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                  color: tema.colorScheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _copiarCodigo(grupo);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  /// Input:
  /// - No recibe parámetros; usa los grupos cargados.
  /// Output:
  /// - `void`: abre la hoja inferior.
  /// Resumen:
  /// - Lista los grupos con su código e integrantes, y ofrece copiar el
  ///   código, salir, unirse o crear un grupo.
  void _abrirMisGrupos() {
    final grupos = _resumen?.grupos ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tema = Theme.of(context);
        final colores = tema.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mis grupos', style: tema.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (grupos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Aún no perteneces a ningún grupo.',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final grupo in grupos)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colores.primaryContainer,
                            child: Text(
                              iniciales(grupo.nombre),
                              style: TextStyle(
                                color: colores.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(grupo.nombre),
                          subtitle: Text(
                            'Código ${grupo.codigo} · '
                            '${grupo.integrantes.length} '
                            '${grupo.integrantes.length == 1 ? 'integrante' : 'integrantes'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Opciones del grupo',
                            onSelected: (accion) {
                              Navigator.pop(context);
                              if (accion == 'copiar') _copiarCodigo(grupo);
                              if (accion == 'salir') _salirDeGrupo(grupo);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'copiar',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy),
                                    SizedBox(width: 16),
                                    Text('Copiar código'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'salir',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: colores.error),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Salir del grupo',
                                      style: TextStyle(color: colores.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _unirseAGrupo();
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Unirme'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _crearGrupo();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Crear grupo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Input:
  /// - No recibe parámetros; usa los grupos y el filtro actual.
  /// Output:
  /// - `Future<void>`: termina al cerrar el formulario.
  /// Resumen:
  /// - Abre el formulario de tarea grupal con el grupo filtrado elegido.
  Future<void> _crearTarea() async {
    final resumen = _resumen;
    if (resumen == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TareaGrupalFormulario(
          grupos: resumen.grupos,
          repositorio: _repositorio,
          gruposRepositorio: _grupos,
          grupoInicial: _filtro,
        ),
      ),
    );
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se abrirá.
  /// - `grupo` (`Grupo`): grupo de la tarea.
  /// Output:
  /// - `Future<void>`: termina al volver del detalle.
  /// Resumen:
  /// - Abre el detalle y recarga los colores al volver.
  Future<void> _abrirTarea(TareaGrupal tarea, Grupo grupo) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TareaGrupalScreen(
          tarea: tarea,
          grupo: grupo,
          repositorio: _repositorio,
          grupos: _grupos,
          colorAsignatura: _colores[tarea.asignatura],
        ),
      ),
    );
    if (mounted) _cargarColores();
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `void`: inicia la navegación al perfil.
  /// Resumen:
  /// - Abre la pantalla de perfil.
  void _abrirPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilScreen(repositorio: _repositorio),
      ),
    );
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `Future<void>`: termina cuando se abre Inicio.
  /// Resumen:
  /// - Navega a Inicio conservando la pila actual.
  Future<void> _abrirInicio() async {
    if (!mounted) return;
    await abrirInicioConservandoPila(
      context,
      builder: (_) => HomeScreen(repositorio: _repositorio),
    );
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `Future<void>`: termina cuando finaliza la navegación a Matriz.
  /// Resumen:
  /// - Navega a la matriz de tareas.
  Future<void> _abrirMatriz() async {
    if (!mounted) return;
    await navegarAPantallaPrincipal(
      context,
      ruta: rutaMatriz,
      builder: (_) => MatrizScreen(repositorio: _repositorio),
    );
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `Future<void>`: termina cuando finaliza la navegación a Pomodoro.
  /// Resumen:
  /// - Navega a Pomodoro como pantalla principal.
  Future<void> _abrirPomodoro() async {
    if (!mounted) return;
    await navegarAPantallaPrincipal(
      context,
      ruta: rutaPomodoro,
      builder: (_) => PomodoroScreen(repositorio: _repositorio),
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema, navegación y widgets.
  /// Output:
  /// - `Widget`: pantalla de tareas grupales.
  /// Resumen:
  /// - Construye el encabezado, el contenido, el botón "Añadir tarea" y la
  ///   navegación inferior con Grupos seleccionado.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final hayGrupos = _resumen?.grupos.isNotEmpty ?? false;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tareas grupales',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mis grupos',
                    onPressed: _resumen == null ? null : _abrirMisGrupos,
                    icon: const Icon(Icons.diversity_3_outlined),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _abrirPerfil,
                    child: Semantics(
                      label: 'Perfil',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: colores.secondaryContainer,
                        child: Icon(
                          Icons.person_outline,
                          color: colores.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _construirContenido(context)),
            ],
          ),
        ),
      ),

      floatingActionButton: hayGrupos
          ? FloatingActionButton.extended(
              onPressed: _crearTarea,
              icon: const Icon(Icons.add),
              label: const Text('Añadir tarea'),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: ColoredBox(
        color: colores.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NavigationBar(
            backgroundColor: colores.surfaceContainer,
            selectedIndex: 3,
            onDestinationSelected: (index) {
              if (index == 0) _abrirInicio();
              if (index == 1) _abrirMatriz();
              if (index == 2) _abrirPomodoro();
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                label: 'Matriz',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                label: 'Pomodoro',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Grupos',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto con el tema actual.
  /// Output:
  /// - `Widget`: estado de carga, error, sin grupos o lista de tareas.
  /// Resumen:
  /// - Construye los filtros por grupo y las tarjetas de tareas grupales.
  Widget _construirContenido(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final resumen = _resumen;

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudieron cargar tus grupos.'),
            TextButton(onPressed: _reintentar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (resumen.grupos.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Card.filled(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_outlined, size: 48, color: colores.primary),
                const SizedBox(height: 16),
                Text('Trabaja en equipo', style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Crea un grupo o únete con el código que te compartieron. '
                  'Las tareas grupales aparecerán aquí, en tu Inicio y en tu calendario.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _crearGrupo,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Crear grupo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _unirseAGrupo,
                  icon: const Icon(Icons.login),
                  label: const Text('Unirme con código'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tareas = [
      for (final tarea in resumen.tareas)
        if (_filtro == null || tarea.grupo == _filtro) tarea,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Todas'),
                selected: _filtro == null,
                onSelected: (_) => setState(() => _filtro = null),
              ),
              for (final grupo in resumen.grupos) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(grupo.nombre),
                  selected: _filtro == grupo.codigo,
                  onSelected: (seleccionado) => setState(
                    () => _filtro = seleccionado ? grupo.codigo : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: tareas.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Card.filled(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay tareas grupales. Pulsa “Añadir tarea” para crear la primera.',
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: tareas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tarea = tareas[index];
                    final grupo = resumen.grupoDe(tarea)!;
                    return TareaGrupalMini(
                      key: ValueKey(tarea.clave),
                      tarea: tarea,
                      grupo: grupo,
                      colorAsignatura: _colores[tarea.asignatura],
                      onTap: () => _abrirTarea(tarea, grupo),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.icono,
    required this.titulo,
    required this.etiqueta,
    required this.ayuda,
    required this.accion,
    required this.largo,
    this.mayusculas = false,
  });

  final IconData icono;
  final String titulo;
  final String etiqueta;
  final String ayuda;
  final String accion;
  final int largo;
  final bool mayusculas;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _formulario = GlobalKey<FormState>();
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// Input:
  /// - No recibe parámetros; usa el campo del diálogo.
  /// Output:
  /// - `void`: cierra el diálogo con el texto escrito.
  /// Resumen:
  /// - Valida el campo y devuelve su texto.
  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(_texto.text.trim());
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto de tema y navegación.
  /// Output:
  /// - `Widget`: diálogo con un campo de texto.
  /// Resumen:
  /// - Construye el diálogo reutilizado para crear un grupo o unirse.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(widget.icono),
      title: Text(widget.titulo),
      content: Form(
        key: _formulario,
        child: TextFormField(
          controller: _texto,
          autofocus: true,
          maxLength: widget.largo,
          textCapitalization: widget.mayusculas
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            helperText: widget.ayuda,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          validator: (valor) => valor == null || valor.trim().isEmpty
              ? 'Completa este campo'
              : null,
          onFieldSubmitted: (_) => _aceptar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: Text(widget.accion)),
      ],
    );
  }
}
