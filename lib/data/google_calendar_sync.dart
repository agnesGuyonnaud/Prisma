import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'tareas_repository.dart';
import '../models/tarea_model.dart';

class GoogleCalendarSyncException implements Exception {
  const GoogleCalendarSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleCalendarSync {
  GoogleCalendarSync({required this.repositorio});

  static const _scopes = [
    'https://www.googleapis.com/auth/calendar.events',
  ];
  static final http.Client _cliente = http.Client();
  static GoogleSignInAccount? _cuentaAutorizada;

  final TareasRepository repositorio;
  final GoogleSignIn _google = GoogleSignIn.instance;

  Future<bool> habilitarYSincronizar() async{
    await Auth().inicializarGoogle();
    if (!_google.supportsAuthenticate()){
      throw const GoogleCalendarSyncException(
        'Google Calendar no está disponible en esta plataforma.',
      );
    }

    late final GoogleSignInAccount cuenta;
    try{
      cuenta = await _google.authenticate();
    } on GoogleSignInException catch (error){
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }

    late final GoogleSignInClientAuthorization autorizacion;
    try{
      autorizacion = await cuenta.authorizationClient.authorizeScopes(_scopes);
    } on GoogleSignInException catch (error){
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      throw const GoogleCalendarSyncException(
        'No se pudo obtener permiso para Google Calendar.',
      );
    }
    _cuentaAutorizada = cuenta;

    final tareas = await repositorio.listar();
    for (final tarea in tareas){
      await _sincronizarTarea(tarea, autorizacion.accessToken);
    }

    await repositorio.guardarEstadoSincronizacionCalendar(
      habilitada: true,
      correo: cuenta.email,
    );
    return true;
  }

  Future<void> deshabilitar() async{
    await repositorio.guardarEstadoSincronizacionCalendar(habilitada: false);
  }

  Future<void> sincronizarTareaSiHabilitada(Tarea tarea) async{
    if (!await repositorio.sincronizacionCalendarHabilitada()) return;
    final cuenta = await _obtenerCuentaAutorizada();
    final correoVinculado = await repositorio.correoCalendarVinculado();
    if (correoVinculado != cuenta.email){
      throw const GoogleCalendarSyncException(
        'La cuenta de Calendar cambió. Vuelve a vincularla desde tu perfil.',
      );
    }
    final autorizacion = await _autorizacionExistente(cuenta);
    if (autorizacion == null){
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }
    await _sincronizarTarea(tarea, autorizacion.accessToken);
  }

  Future<void> eliminarEventoSiHabilitado(int tareaId) async{
    if (!await repositorio.sincronizacionCalendarHabilitada()) return;
    final eventoId = await repositorio.idEventoCalendar(tareaId);
    if (eventoId == null) return;

    final cuenta = await _obtenerCuentaAutorizada();
    final correoVinculado = await repositorio.correoCalendarVinculado();
    if (correoVinculado != cuenta.email){
      throw const GoogleCalendarSyncException(
        'La cuenta de Calendar cambió. Vuelve a vincularla desde tu perfil.',
      );
    }
    final autorizacion = await _autorizacionExistente(cuenta);
    if (autorizacion == null){
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }

    final respuesta = await _enviar(
      () => _cliente.delete(
        _uriEvento(eventoId),
        headers: _headers(autorizacion.accessToken),
      ),
    );
    if (respuesta.statusCode != 204 && respuesta.statusCode != 404){
      throw _errorApi(respuesta.statusCode);
    }
  }

  Future<GoogleSignInAccount> _obtenerCuentaAutorizada() async{
    await Auth().inicializarGoogle();
    final cuentaEnMemoria = _cuentaAutorizada;
    if (cuentaEnMemoria != null) return cuentaEnMemoria;

    late final GoogleSignInAccount? cuenta;
    try{
      final intento = _google.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      cuenta = intento == null ? null : await intento;
    } on GoogleSignInException{
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }
    if (cuenta == null){
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }
    _cuentaAutorizada = cuenta;
    return cuenta;
  }

  Future<GoogleSignInClientAuthorization?> _autorizacionExistente(
    GoogleSignInAccount cuenta,
  ) async{
    try{
      return await cuenta.authorizationClient.authorizationForScopes(_scopes);
    } on GoogleSignInException{
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }
  }

  Future<void> _sincronizarTarea(Tarea tarea, String accessToken) async{
    final tareaId = tarea.id;
    if (tareaId == null){
      throw const GoogleCalendarSyncException(
        'No se puede sincronizar una tarea que aún no está guardada.',
      );
    }

    final eventoId = await repositorio.idEventoCalendar(tareaId);
    final datosEvento = jsonEncode({
      'summary': tarea.titulo,
      'description': 'Asignatura: ${tarea.asignatura}\nTipo: ${tarea.tipo}',
      'start': {
        'dateTime': tarea.fechaLimite.toUtc().toIso8601String(),
      },
      'end': {
        'dateTime': tarea.fechaLimite
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      },
    });

    if (eventoId != null){
      final respuesta = await _enviar(
        () => _cliente.patch(
          _uriEvento(eventoId),
          headers: _headers(accessToken),
          body: datosEvento,
        ),
      );
      if (respuesta.statusCode == 200) return;
      if (respuesta.statusCode != 404){
        throw _errorApi(respuesta.statusCode);
      }
    }

    final respuesta = await _enviar(
      () => _cliente.post(
        _uriEventos,
        headers: _headers(accessToken),
        body: datosEvento,
      ),
    );
    if (respuesta.statusCode != 200 && respuesta.statusCode != 201){
      throw _errorApi(respuesta.statusCode);
    }
    final evento = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final nuevoEventoId = evento['id'] as String?;
    if (nuevoEventoId == null){
      throw const GoogleCalendarSyncException(
        'Google Calendar no devolvió el identificador del evento.',
      );
    }
    await repositorio.guardarIdEventoCalendar(tareaId, nuevoEventoId);
  }

  Future<http.Response> _enviar(Future<http.Response> Function() solicitud) async{
    try{
      return await solicitud();
    } on http.ClientException{
      throw const GoogleCalendarSyncException(
        'No se pudo conectar con Google Calendar. Revisa tu conexión.',
      );
    }
  }

  Uri _uriEvento(String id) =>
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events/$id');

  Uri get _uriEventos =>
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events');

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  GoogleCalendarSyncException _errorApi(int statusCode){
    if (statusCode == 401 || statusCode == 403){
      return const GoogleCalendarSyncException(
        'Google rechazó el acceso. Vuelve a vincular Calendar desde tu perfil.',
      );
    }
    return GoogleCalendarSyncException(
      'Google Calendar respondió con un error ($statusCode).',
    );
  }
}
