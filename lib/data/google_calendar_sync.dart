import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'tareas_repository.dart';
// TareaGrupal para sincronizar las tareas de los grupos.
import '../models/grupo_model.dart';
import '../models/tarea_model.dart';

class GoogleCalendarSyncException implements Exception {
  const GoogleCalendarSyncException(this.message);

  final String message;

  /// Input:
  /// - No recibe parámetros; usa el mensaje de esta excepción.
  /// Output:
  /// - `String`: descripción legible del error.
  /// Resumen:
  /// - Expone el mensaje de la excepción como su representación textual.
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

  /// Input:
  /// - No recibe parámetros; usa el repositorio y la cuenta de Google elegida.
  /// Output:
  /// - `Future<bool>`: `true` si completó la sincronización o `false` si se canceló.
  /// Resumen:
  /// - Autoriza Calendar, sincroniza tareas existentes y guarda la preferencia.
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

  /// Input:
  /// - No recibe parámetros; usa el repositorio asociado a este sincronizador.
  /// Output:
  /// - `Future<void>`: termina al guardar la preferencia desactivada.
  /// Resumen:
  /// - Desactiva la sincronización sin borrar los eventos ya creados.
  Future<void> deshabilitar() async{
    await repositorio.guardarEstadoSincronizacionCalendar(habilitada: false);
  }

  /// Input:
  /// - `tarea` (`Tarea`): tarea que se creará o actualizará en Calendar.
  /// Output:
  /// - `Future<void>`: termina al sincronizar o si la sincronización está apagada.
  /// Resumen:
  /// - Valida la cuenta y permisos, y sincroniza una tarea si está habilitado.
  Future<void> sincronizarTareaSiHabilitada(Tarea tarea) async{
    if (!await repositorio.sincronizacionCalendarHabilitada()) return;
    await _sincronizarTarea(tarea, await _tokenVigente());
  }

  static Future<void> _colaGrupales = Future.value();

  /// Input:
  /// - `tareas` (`List<TareaGrupal>`): todas las tareas grupales del usuario.
  /// Output:
  /// - `Future<void>`: termina cuando se procesa esta sincronización.
  /// Resumen:
  /// - Encola la sincronización para que dos llamadas seguidas no creen
  ///   eventos duplicados.
  Future<void> sincronizarTareasGrupalesSiHabilitada(List<TareaGrupal> tareas){
    final siguiente = _colaGrupales
        .catchError((_){})
        .then((_) => _sincronizarTareasGrupales(tareas));
    _colaGrupales = siguiente;
    return siguiente;
  }

  /// Input:
  /// - `tareas` (`List<TareaGrupal>`): todas las tareas grupales del usuario.
  /// Output:
  /// - `Future<void>`: termina al actualizar Calendar.
  /// Resumen:
  /// - Crea o actualiza solo los eventos que cambiaron y borra los de
  ///   tareas que ya no existen.
  Future<void> _sincronizarTareasGrupales(List<TareaGrupal> tareas) async{
    if(!await repositorio.sincronizacionCalendarHabilitada()) return;
    final guardados = await repositorio.eventosCalendarGrupales();
    String? token;
    for(final tarea in tareas){
      final datosEvento = _datosEventoGrupal(tarea);
      final guardado = guardados.remove(tarea.clave);
      if(guardado != null && guardado['datos'] == datosEvento) continue;
      token ??= await _tokenVigente();
      final eventoId = await _publicarEvento(
        guardado?['evento'] as String?,
        datosEvento,
        token,
      );
      await repositorio.guardarEventoCalendarGrupal(
        tarea.clave,
        eventoId,
        datosEvento,
      );
    }
    for(final entrada in guardados.entries){
      token ??= await _tokenVigente();
      await _eliminarEvento(entrada.value['evento'] as String, token);
      await repositorio.eliminarEventoCalendarGrupal(entrada.key);
    }
  }

  /// Input:
  /// - `tarea` (`TareaGrupal`): tarea que se convertirá en evento.
  /// Output:
  /// - `String`: JSON del evento para la API de Calendar.
  /// Resumen:
  /// - Arma el título, descripción y horario del evento grupal.
  String _datosEventoGrupal(TareaGrupal tarea) => jsonEncode({
    'summary': tarea.titulo,
    'description':
        'Tarea grupal\nAsignatura: ${tarea.asignatura}\n'
        'Estado: ${tarea.estado.etiqueta}',
    'start': {'dateTime': tarea.fechaLimite.toUtc().toIso8601String()},
    'end': {
      'dateTime': tarea.fechaLimite
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    },
  });

  /// Input:
  /// - No recibe parámetros; usa la cuenta vinculada en preferencias.
  /// Output:
  /// - `Future<String>`: token de acceso para la API de Calendar.
  /// Resumen:
  /// - Verifica que la cuenta y los permisos sigan vigentes y entrega el token.
  Future<String> _tokenVigente() async{
    final cuenta = await _obtenerCuentaAutorizada();
    final correoVinculado = await repositorio.correoCalendarVinculado();
    if(correoVinculado != cuenta.email){
      throw const GoogleCalendarSyncException(
        'La cuenta de Calendar cambió. Vuelve a vincularla desde tu perfil.',
      );
    }
    final autorizacion = await _autorizacionExistente(cuenta);
    if(autorizacion == null){
      throw const GoogleCalendarSyncException(
        'Vuelve a vincular Google Calendar desde tu perfil para sincronizar.',
      );
    }
    return autorizacion.accessToken;
  }

  /// Input:
  /// - `tareaId` (`int`): identificador local de la tarea a eliminar.
  /// Output:
  /// - `Future<void>`: termina al eliminar el evento o si no aplica.
  /// Resumen:
  /// - Elimina de Calendar el evento asociado cuando la sincronización está activa.
  Future<void> eliminarEventoSiHabilitado(int tareaId) async{
    if (!await repositorio.sincronizacionCalendarHabilitada()) return;
    final eventoId = await repositorio.idEventoCalendar(tareaId);
    if (eventoId == null) return;
    await _eliminarEvento(eventoId, await _tokenVigente());
  }

  /// Input:
  /// - `eventoId` (`String`): ID del evento en Calendar.
  /// - `accessToken` (`String`): token de acceso para la API.
  /// Output:
  /// - `Future<void>`: termina al borrar el evento.
  /// Resumen:
  /// - Elimina el evento, ignorando si ya no existía.
  Future<void> _eliminarEvento(String eventoId, String accessToken) async{
    final respuesta = await _enviar(
      () => _cliente.delete(
        _uriEvento(eventoId),
        headers: _headers(accessToken),
      ),
    );
    if(respuesta.statusCode != 204 &&
        respuesta.statusCode != 404 &&
        respuesta.statusCode != 410){
      throw _errorApi(respuesta.statusCode);
    }
  }

  /// Input:
  /// - No recibe parámetros; consulta la cuenta vinculada o autenticación ligera.
  /// Output:
  /// - `Future<GoogleSignInAccount>`: cuenta Google autorizada para Calendar.
  /// Resumen:
  /// - Recupera la cuenta autorizada o solicita volver a vincularla.
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

  /// Input:
  /// - `cuenta` (`GoogleSignInAccount`): cuenta para consultar permisos actuales.
  /// Output:
  /// - `Future<GoogleSignInClientAuthorization?>`: autorización existente o `null`.
  /// Resumen:
  /// - Consulta los permisos Calendar ya concedidos sin iniciar otro consentimiento.
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

  /// Input:
  /// - `tarea` (`Tarea`): tarea que se reflejará en Calendar.
  /// - `accessToken` (`String`): token de acceso para la API de Calendar.
  /// Output:
  /// - `Future<void>`: termina al crear o actualizar el evento localmente vinculado.
  /// Resumen:
  /// - Actualiza el evento existente o crea uno nuevo y guarda su identificador.
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

    final nuevoEventoId = await _publicarEvento(
      eventoId,
      datosEvento,
      accessToken,
    );
    if(nuevoEventoId != eventoId){
      await repositorio.guardarIdEventoCalendar(tareaId, nuevoEventoId);
    }
  }

  /// Input:
  /// - `eventoId` (`String?`): ID del evento existente, si lo hay.
  /// - `datosEvento` (`String`): JSON del evento.
  /// - `accessToken` (`String`): token de acceso para la API.
  /// Output:
  /// - `Future<String>`: ID del evento actualizado o creado.
  /// Resumen:
  /// - Actualiza el evento existente o crea uno nuevo si no existe.
  Future<String> _publicarEvento(
    String? eventoId,
    String datosEvento,
    String accessToken,
  ) async{
    if (eventoId != null){
      final respuesta = await _enviar(
        () => _cliente.patch(
          _uriEvento(eventoId),
          headers: _headers(accessToken),
          body: datosEvento,
        ),
      );
      if (respuesta.statusCode == 200) return eventoId;
      if (respuesta.statusCode != 404 && respuesta.statusCode != 410){
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
    return nuevoEventoId;
  }

  /// Input:
  /// - `solicitud` (`Future<http.Response> Function()`): llamada HTTP a ejecutar.
  /// Output:
  /// - `Future<http.Response>`: respuesta del servidor o excepción traducida.
  /// Resumen:
  /// - Ejecuta una llamada y convierte errores de conexión en errores de dominio.
  Future<http.Response> _enviar(Future<http.Response> Function() solicitud) async{
    try{
      return await solicitud();
    } on http.ClientException{
      throw const GoogleCalendarSyncException(
        'No se pudo conectar con Google Calendar. Revisa tu conexión.',
      );
    }
  }

  /// Input:
  /// - `id` (`String`): identificador del evento en Google Calendar.
  /// Output:
  /// - `Uri`: dirección de la API para ese evento.
  /// Resumen:
  /// - Construye la URL del evento en el calendario principal.
  Uri _uriEvento(String id) =>
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events/$id');

  /// Input:
  /// - No recibe parámetros; utiliza el calendario principal de la cuenta.
  /// Output:
  /// - `Uri`: URL de la colección de eventos de Calendar.
  /// Resumen:
  /// - Construye la URL base para crear eventos.
  Uri get _uriEventos =>
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events');

  /// Input:
  /// - `token` (`String`): token de acceso para autorizar la API.
  /// Output:
  /// - `Map<String, String>`: encabezados HTTP de autenticación y JSON.
  /// Resumen:
  /// - Prepara los encabezados comunes de las solicitudes a Calendar.
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// Input:
  /// - `statusCode` (`int`): código HTTP de error de Google Calendar.
  /// Output:
  /// - `GoogleCalendarSyncException`: error con mensaje apropiado para el usuario.
  /// Resumen:
  /// - Traduce respuestas HTTP fallidas a errores de sincronización.
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
