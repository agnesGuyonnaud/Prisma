import 'dart:async';

import 'package:flutter/material.dart';

import '../data/pomodoro_notifications.dart';
import '../data/tareas_repository.dart';
import '../models/asignatura_model.dart';
import 'asignaturas.dart';
import 'home.dart';
import 'matriz.dart';
import 'perfil.dart';
import '../utils/navegacion_principal.dart';

enum _FasePomodoro { estudio, descanso }

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({
    super.key,
    this.repositorio,
    this.notificaciones,
    this.reloj,
  });

  final TareasRepository? repositorio;
  final PomodoroNotificaciones? notificaciones;
  final DateTime Function()? reloj;

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with WidgetsBindingObserver {
  static const _segundosAntesDeGuardar = 30;

  late final TareasRepository _repositorio;
  late final PomodoroNotificaciones _notificaciones;
  final _minutosEstudioController = TextEditingController();
  final _minutosDescansoController = TextEditingController();
  final _formAjustes = GlobalKey<FormState>();

  List<Asignatura> _asignaturas = [];
  String? _asignatura;
  String? _asignaturaActiva;
  String? _errorAsignaturas;
  String? _errorGuardado;
  Timer? _timer;
  Future<void>? _guardadoEnCurso;
  Future<void>? _sincronizacionEnCurso;
  DateTime? _finDeFase;
  DateTime? _ultimoAvance;
  Duration _tiempoRestante = const Duration(minutes: 25);
  _FasePomodoro _fase = _FasePomodoro.estudio;
  int _minutosEstudio = 25;
  int _minutosDescanso = 5;
  int _segundosPendientes = 0;
  int _milisegundosEstudioRestantes = 0;
  int _pomodorosCompletados = 0;
  bool _cargandoAsignaturas = true;
  bool _enMarcha = false;

  /// Input:
  /// - No recibe parámetros; usa el reloj inyectado o el reloj del sistema.
  /// Output:
  /// - `DateTime`: instante actual de referencia para el temporizador.
  /// Resumen:
  /// - Centraliza el reloj real o el reloj controlado por pruebas.
  DateTime get _ahora => widget.reloj?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? TareasRepository.instancia;
    _notificaciones =
        widget.notificaciones ?? NotificacionesLocalesPomodoro.instancia;
    WidgetsBinding.instance.addObserver(this);
    _cargarAsignaturas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _minutosEstudioController.dispose();
    _minutosDescansoController.dispose();
    if (_segundosPendientes > 0) {
      unawaited(
        _guardarTiempoPendiente().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('No se pudo guardar el tiempo de estudio: $error');
        }),
      );
    }
    unawaited(
      _notificaciones.cancelar().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('No se pudieron cancelar los avisos Pomodoro: $error');
      }),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(
        _sincronizarTemporizador(guardarTodo: true)
            .catchError((Object error, StackTrace stackTrace) {
              _errorGuardado = error.toString();
              debugPrint('No se pudo guardar el tiempo de estudio: $error');
            }),
      );
    } else if (state == AppLifecycleState.resumed) {
      unawaited(
        _sincronizarTemporizador()
            .then((_) {
              if (_enMarcha) {
                return _programarAvisos().catchError(_registrarErrorAvisos);
              }
            })
            .catchError(_notificarErrorGuardado),
      );
      if (_errorGuardado != null) _mostrarErrorGuardado(_errorGuardado!);
    }
  }

  /// Input:
  /// - No recibe parámetros; consulta las asignaturas del repositorio.
  /// Output:
  /// - `Future<void>`: termina al actualizar la lista de asignaturas.
  /// Resumen:
  /// - Carga las asignaturas disponibles para asociar al tiempo de estudio.
  Future<void> _cargarAsignaturas() async {
    setState(() {
      _cargandoAsignaturas = true;
      _errorAsignaturas = null;
    });
    try {
      final lista = await _repositorio.listarAsignaturas();
      if (!mounted) return;
      setState(() {
        _asignaturas = lista;
        _cargandoAsignaturas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoAsignaturas = false;
        _errorAsignaturas = 'No se pudieron cargar las asignaturas: $error';
      });
    }
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `Future<void>`: termina al guardar o cancelar la creación.
  /// Resumen:
  /// - Abre el diálogo de asignatura y actualiza la selección al guardarla.
  Future<void> _crearAsignatura() async {
    final nueva = await mostrarDialogoAsignatura(
      context: context,
      repositorio: _repositorio,
    );
    if (nueva == null || !mounted) return;
    await _cargarAsignaturas();
    if (!mounted) return;
    setState(() => _asignatura = nueva.nombre);
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `Future<void>`: termina cuando se cierra la pantalla de Inicio.
  /// Resumen:
  /// - Abre Inicio conservando el Pomodoro en la pila de navegación.
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
  /// - `Future<void>`: termina cuando se cierra la Matriz.
  /// Resumen:
  /// - Abre Matriz encima de Pomodoro para conservar su estado.
  Future<void> _abrirMatriz() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: rutaMatriz),
        builder: (_) => MatrizScreen(repositorio: _repositorio),
      ),
    );
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
  /// - No recibe parámetros; utiliza el estado actual del temporizador.
  /// Output:
  /// - `Future<void>`: termina al iniciar o pausar y guardar el avance.
  /// Resumen:
  /// - Alterna el temporizador y coordina sus avisos y el registro de estudio.
  Future<void> _alternarTemporizador() async {
    if (_enMarcha) {
      await _sincronizarTemporizador();
      _timer?.cancel();
      setState(() {
        _enMarcha = false;
        _finDeFase = null;
        _ultimoAvance = null;
      });
      try {
        await _notificaciones.cancelar();
      } catch (error) {
        _notificarErrorCancelarAvisos(error);
      }
      try {
        await _guardarTiempoPendiente();
      } catch (error) {
        _mostrarErrorGuardado(error);
      }
      return;
    }

    if (_fase == _FasePomodoro.estudio && _asignatura == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una asignatura primero.')),
      );
      return;
    }

    var permisosAvisos = false;
    try {
      permisosAvisos = await _notificaciones.preparar();
    } catch (error) {
      debugPrint('No se pudieron preparar los avisos Pomodoro: $error');
    }

    try {
      await _guardarTiempoPendiente();
    } catch (error) {
      _mostrarErrorGuardado(error);
      return;
    }
    if (!mounted) return;
    final ahora = _ahora;
    if (_fase == _FasePomodoro.estudio) {
      _asignaturaActiva = _asignatura;
    }
    setState(() {
      _enMarcha = true;
      _ultimoAvance = ahora;
      _finDeFase = ahora.add(_tiempoRestante);
    });
    _iniciarReloj();
    if (permisosAvisos) {
      if (_notificaciones is NotificacionesLocalesPomodoro &&
          !_notificaciones.permiteAlarmasExactas) {
        _mostrarAvisoAlarmasInexactas();
      } else {
        try {
          await _programarAvisos();
        } catch (error) {
          _registrarErrorAvisos(error);
        }
      }
    } else if (_notificaciones is NotificacionesLocalesPomodoro) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El temporizador seguirá funcionando, pero debes permitir las notificaciones para recibir avisos con sonido.',
          ),
        ),
      );
    }
  }

  /// Input:
  /// - No recibe parámetros; presenta instrucciones para configurar Android.
  /// Output:
  /// - `void`: muestra un aviso con una acción para pedir permiso.
  /// Resumen:
  /// - Informa que los avisos no se programan sin permiso de alarmas exactas.
  void _mostrarAvisoAlarmasInexactas() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Activa las alarmas exactas para recibir avisos a tiempo. '
            'Sin ese permiso no se programarán avisos.',
          ),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Configurar',
            onPressed: () async {
              try {
                final permitidas = await _notificaciones
                    .solicitarAlarmasExactas();
                if (!mounted) return;
                if (permitidas && _enMarcha) {
                  await _programarAvisos();
                } else if (!permitidas) {
                  _mostrarAvisoAlarmasInexactas();
                }
              } catch (error) {
                _registrarErrorAvisos(error);
              }
            },
          ),
        ),
      );
  }

  /// Input:
  /// - No recibe parámetros; usa el temporizador y sincronizador de la pantalla.
  /// Output:
  /// - `void`: inicia un reloj periódico de actualización.
  /// Resumen:
  /// - Actualiza el temporizador cada segundo mientras está en marcha.
  void _iniciarReloj() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(
        _sincronizarTemporizador().catchError(_notificarErrorGuardado),
      ),
    );
  }

  /// Input:
  /// - `guardarTodo` (`bool`): fuerza el guardado del avance pendiente.
  /// Output:
  /// - `Future<void>`: completa la sincronización en curso o la inicia.
  /// Resumen:
  /// - Evita sincronizaciones simultáneas y mantiene el tiempo al día.
  Future<void> _sincronizarTemporizador({bool guardarTodo = false}) {
    final actualizacionEnCurso = _sincronizacionEnCurso;
    if (actualizacionEnCurso != null) {
      return actualizacionEnCurso.then((_) {
        final ultimoAvance = _ultimoAvance;
        if (_enMarcha &&
            (guardarTodo ||
                ultimoAvance == null ||
                _ahora.isAfter(ultimoAvance))) {
          return _sincronizarTemporizador(guardarTodo: guardarTodo);
        }
      });
    }

    final actualizacion = _procesarAvance(guardarTodo: guardarTodo);
    _sincronizacionEnCurso = actualizacion;
    return actualizacion.whenComplete(() {
      if (identical(_sincronizacionEnCurso, actualizacion)) {
        _sincronizacionEnCurso = null;
      }
    });
  }

  /// Input:
  /// - `guardarTodo` (`bool`): indica si debe persistir todo el avance actual.
  /// Output:
  /// - `Future<void>`: termina al actualizar fases y persistir tiempo pendiente.
  /// Resumen:
  /// - Calcula el tiempo transcurrido y procesa los cambios de fase.
  Future<void> _procesarAvance({required bool guardarTodo}) async {
    final finInicial = _finDeFase;
    if (!_enMarcha || finInicial == null) return;

    final ahora = _ahora;
    var cursor = _ultimoAvance ?? ahora;
    var finDeFase = finInicial;
    while (!ahora.isBefore(finDeFase)) {
      if (_fase == _FasePomodoro.estudio) {
        _acumularTiempoEstudio(finDeFase.difference(cursor));
        _pomodorosCompletados++;
        _fase = _FasePomodoro.descanso;
      } else {
        _fase = _FasePomodoro.estudio;
      }
      cursor = finDeFase;
      finDeFase = finDeFase.add(_duracionDe(_fase));
    }
    if (ahora.isAfter(cursor) && _fase == _FasePomodoro.estudio) {
      _acumularTiempoEstudio(ahora.difference(cursor));
    }

    _ultimoAvance = ahora;
    _finDeFase = finDeFase;
    _tiempoRestante = finDeFase.difference(ahora);
    if (mounted) setState(() {});

    if (_segundosPendientes >= _segundosAntesDeGuardar || guardarTodo) {
      await _guardarTiempoPendiente();
    }
  }

  /// Input:
  /// - `transcurrido` (`Duration`): intervalo de estudio que se sumará.
  /// Output:
  /// - `void`: actualiza el acumulado pendiente de guardar.
  /// Resumen:
  /// - Acumula milisegundos y conserva los segundos completos de estudio.
  void _acumularTiempoEstudio(Duration transcurrido) {
    final milisegundos = transcurrido.inMilliseconds;
    if (milisegundos <= 0) return;
    final total = _milisegundosEstudioRestantes + milisegundos;
    _segundosPendientes += total ~/ Duration.millisecondsPerSecond;
    _milisegundosEstudioRestantes = total % Duration.millisecondsPerSecond;
  }

  /// Input:
  /// - `fase` (`_FasePomodoro`): fase de estudio o descanso.
  /// Output:
  /// - `Duration`: duración configurada para esa fase.
  /// Resumen:
  /// - Convierte la fase actual en su duración correspondiente.
  Duration _duracionDe(_FasePomodoro fase) => Duration(
    minutes: fase == _FasePomodoro.estudio ? _minutosEstudio : _minutosDescanso,
  );

  /// Input:
  /// - No recibe parámetros; utiliza la fase y hora de finalización actuales.
  /// Output:
  /// - `Future<void>`: termina al solicitar la programación de los avisos.
  /// Resumen:
  /// - Genera y programa avisos para las siguientes fases Pomodoro.
  Future<void> _programarAvisos() async {
    final primerFin = _finDeFase;
    if (!_enMarcha || primerFin == null) return;
    var fase = _fase;
    var fecha = primerFin;
    final avisos = <PomodoroAviso>[];
    for (var index = 0; index < 60; index++) {
      final terminaEstudio = fase == _FasePomodoro.estudio;
      avisos.add(
        PomodoroAviso(
          fecha: fecha,
          titulo: terminaEstudio
              ? 'Terminó el tiempo de estudio'
              : 'Terminó el descanso',
          mensaje: terminaEstudio
              ? 'Es hora de tomar un descanso.'
              : 'Es hora de volver al estudio.',
        ),
      );
      fase = terminaEstudio ? _FasePomodoro.descanso : _FasePomodoro.estudio;
      fecha = fecha.add(_duracionDe(fase));
    }
    await _notificaciones.programar(avisos);
  }

  /// Input:
  /// - `error` (`Object`): error producido al preparar o programar avisos.
  /// Output:
  /// - `void`: registra el error en la consola.
  /// Resumen:
  /// - Conserva el detalle técnico sin interrumpir al usuario con un aviso.
  void _registrarErrorAvisos(Object error) {
    debugPrint('No se pudieron programar los avisos Pomodoro: $error');
  }

  /// Input:
  /// - `error` (`Object`): error producido al cancelar avisos.
  /// Output:
  /// - `void`: registra el error y puede mostrar una notificación en pantalla.
  /// Resumen:
  /// - Informa que no fue posible cancelar avisos programados.
  void _notificarErrorCancelarAvisos(Object error) {
    debugPrint('No se pudieron cancelar los avisos Pomodoro: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron cancelar los avisos Pomodoro. '
            'Revisa los permisos de notificaciones.',
          ),
        ),
      );
  }

  /// Input:
  /// - No recibe parámetros; usa la fase y configuración actuales.
  /// Output:
  /// - `Future<void>`: termina al detener y reiniciar el temporizador.
  /// Resumen:
  /// - Cancela avisos, guarda el tiempo pendiente y vuelve al inicio del ciclo.
  Future<void> _reiniciar() async {
    await _sincronizarTemporizador();
    _timer?.cancel();
    setState(() {
      _enMarcha = false;
      _finDeFase = null;
      _ultimoAvance = null;
    });
    try {
      await _notificaciones.cancelar();
    } catch (error) {
      _notificarErrorCancelarAvisos(error);
    }
    try {
      await _guardarTiempoPendiente();
    } catch (error) {
      _mostrarErrorGuardado(error);
      return;
    }
    if (!mounted) return;
    setState(() {
      _fase = _FasePomodoro.estudio;
      _tiempoRestante = Duration(minutes: _minutosEstudio);
      _pomodorosCompletados = 0;
      _asignaturaActiva = null;
      _milisegundosEstudioRestantes = 0;
    });
  }

  /// Input:
  /// - No recibe parámetros; usa los segundos pendientes y la asignatura activa.
  /// Output:
  /// - `Future<void>`: termina cuando todo el tiempo pendiente queda guardado.
  /// Resumen:
  /// - Persiste el avance de estudio evitando duplicar guardados concurrentes.
  Future<void> _guardarTiempoPendiente() async {
    if (_segundosPendientes == 0) return;

    final guardadoExistente = _guardadoEnCurso;
    if (guardadoExistente != null) {
      await guardadoExistente;
      return _guardarTiempoPendiente();
    }

    final asignatura = _asignaturaActiva;
    if (asignatura == null) {
      throw StateError('No hay asignatura asociada al tiempo de estudio.');
    }
    final segundos = _segundosPendientes;
    final guardado = _repositorio.registrarTiempoEstudio(
      asignatura: asignatura,
      segundos: segundos,
    );
    _guardadoEnCurso = guardado;
    try {
      await guardado;
      _segundosPendientes -= segundos;
      _errorGuardado = null;
      if (mounted) setState(() {});
    } finally {
      if (identical(_guardadoEnCurso, guardado)) {
        _guardadoEnCurso = null;
      }
    }
    if (_segundosPendientes > 0) return _guardarTiempoPendiente();
  }

  /// Input:
  /// - `error` (`Object`): error producido al guardar tiempo de estudio.
  /// Output:
  /// - `void`: registra el error y actualiza el mensaje visible.
  /// Resumen:
  /// - Informa que el guardado falló y que se reintentará.
  void _notificarErrorGuardado(Object error) {
    _errorGuardado = error.toString();
    debugPrint('No se pudo guardar el tiempo de estudio: $error');
    if (mounted) _mostrarErrorGuardado(error);
  }

  /// Input:
  /// - `error` (`Object`): detalle del fallo que se comunicará al usuario.
  /// Output:
  /// - `void`: actualiza el estado y muestra un mensaje en pantalla.
  /// Resumen:
  /// - Indica que el tiempo no se guardó y se conservará para reintentar.
  void _mostrarErrorGuardado(Object error) {
    if (!mounted) return;
    setState(() => _errorGuardado = error.toString());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el tiempo de estudio. Se conservará para reintentar.',
          ),
        ),
      );
  }

  /// Input:
  /// - No recibe parámetros; usa la duración configurada en el temporizador.
  /// Output:
  /// - `Future<void>`: termina al guardar o cancelar los ajustes.
  /// Resumen:
  /// - Valida y aplica las duraciones de estudio y descanso.
  Future<void> _mostrarAjustes() async {
    if (_enMarcha) return;
    _minutosEstudioController.text = _minutosEstudio.toString();
    _minutosDescansoController.text = _minutosDescanso.toString();

    final ajustes = await showDialog<_DuracionesPomodoro>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustes del Pomodoro'),
        content: Form(
          key: _formAjustes,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _minutosEstudioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tiempo de estudio (minutos)',
                ),
                validator: _validarMinutos,
              ),
              TextFormField(
                controller: _minutosDescansoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tiempo de descanso (minutos)',
                ),
                validator: _validarMinutos,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formAjustes.currentState!.validate()) return;
              Navigator.of(context).pop(
                _DuracionesPomodoro(
                  estudio: int.parse(_minutosEstudioController.text),
                  descanso: int.parse(_minutosDescansoController.text),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ajustes == null || !mounted) return;
    setState(() {
      _minutosEstudio = ajustes.estudio;
      _minutosDescanso = ajustes.descanso;
      _tiempoRestante = Duration(
        minutes: _fase == _FasePomodoro.estudio
            ? _minutosEstudio
            : _minutosDescanso,
      );
    });
  }

  /// Input:
  /// - `valor` (`String?`): minutos ingresados para una fase.
  /// Output:
  /// - `String?`: mensaje de error o `null` cuando el valor es válido.
  /// Resumen:
  /// - Verifica que la duración sea un entero entre 1 y 180 minutos.
  String? _validarMinutos(String? valor) {
    final minutos = int.tryParse(valor ?? '');
    if (minutos == null || minutos < 1 || minutos > 180) {
      return 'Ingresa un número entre 1 y 180.';
    }
    return null;
  }

  /// Input:
  /// - No recibe parámetros; utiliza el tiempo restante actual.
  /// Output:
  /// - `String`: cuenta regresiva con el formato `mm:ss`.
  /// Resumen:
  /// - Convierte el tiempo restante en el texto del contador.
  String get _textoRestante {
    final minutos = _tiempoRestante.inMinutes;
    final segundos = _tiempoRestante.inSeconds.remainder(60);
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }

  /// Input:
  /// - No recibe parámetros; utiliza la fase seleccionada.
  /// Output:
  /// - `Duration`: duración configurada para la fase actual.
  /// Resumen:
  /// - Expone la duración de fase usada para calcular el progreso circular.
  Duration get _duracionFase => _duracionDe(_fase);

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema, navegación y widgets.
  /// Output:
  /// - `Widget`: devuelve la pantalla del temporizador Pomodoro.
  /// Resumen:
  /// - Construye el selector, contador, ajustes y navegación del temporizador.
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final porcentaje = _duracionFase.inSeconds == 0
        ? 0.0
        : 1 - (_tiempoRestante.inSeconds / _duracionFase.inSeconds);
    final puedeCambiarAsignatura = !_enMarcha && _segundosPendientes == 0;

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
                      'Temporizador Pomodoro',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                key: ValueKey('asignatura_$_asignatura'),
                initialValue: _asignatura,
                isExpanded: true,
                hint: const Text('Selecciona una asignatura'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: [
                  for (final asignatura in _asignaturas)
                    DropdownMenuItem<String>(
                      value: asignatura.nombre,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: asignatura.color,
                            radius: 6,
                          ),
                          const SizedBox(width: 8),
                          Text(asignatura.nombre),
                        ],
                      ),
                    ),
                  const DropdownMenuItem<String>(
                    value: '__NUEVA_ASIGNATURA__',
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Nueva asignatura',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: !_cargandoAsignaturas && puedeCambiarAsignatura
                    ? (valor) {
                        if (valor == '__NUEVA_ASIGNATURA__') {
                          _crearAsignatura();
                        } else {
                          setState(() => _asignatura = valor);
                        }
                      }
                    : null,
              ),
              if (_cargandoAsignaturas)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_errorAsignaturas != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _errorAsignaturas!,
                          style: TextStyle(color: colores.error),
                        ),
                      ),
                      TextButton(
                        onPressed: _cargarAsignaturas,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diametro = (constraints.maxHeight - 116)
                        .clamp(140.0, 240.0)
                        .toDouble();
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final activo = index == _pomodorosCompletados % 4;
                              return Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activo
                                      ? colores.onSurface
                                      : colores.onSurface.withValues(
                                          alpha: 0.16,
                                        ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: diametro,
                            height: diametro,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: porcentaje.clamp(0.0, 1.0),
                                    strokeWidth: 6,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: colores.outlineVariant,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colores.onSurface.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _asignatura == null
                                          ? '-'
                                          : _textoRestante,
                                      style: tema.textTheme.displaySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                    if (_asignatura != null)
                                      Text(
                                        _fase == _FasePomodoro.estudio
                                            ? 'Estudio'
                                            : 'Descanso',
                                        style: tema.textTheme.bodyMedium,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Reiniciar Pomodoro',
                                onPressed: _reiniciar,
                                icon: const Icon(Icons.refresh),
                                iconSize: 28,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: FilledButton(
                                  onPressed: _alternarTemporizador,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Icon(
                                    _enMarcha ? Icons.pause : Icons.play_arrow,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Ajustes de tiempo',
                                onPressed: _enMarcha ? null : _mostrarAjustes,
                                icon: const Icon(Icons.tune),
                                iconSize: 28,
                              ),
                            ],
                          ),
                          if (_segundosPendientes > 0 &&
                              !_enMarcha &&
                              _errorGuardado != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Tiempo de estudio pendiente de guardar',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: colores.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: colores.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NavigationBar(
            backgroundColor: colores.surfaceContainer,
            selectedIndex: 2,
            onDestinationSelected: (index) {
              if (index == 0) _abrirInicio();
              if (index == 1) _abrirMatriz();
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
                selectedIcon: Icon(Icons.access_time),
                label: 'Pomodoro',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                label: 'Grupos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuracionesPomodoro {
  const _DuracionesPomodoro({required this.estudio, required this.descanso});

  final int estudio;
  final int descanso;
}
