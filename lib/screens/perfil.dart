import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth.dart';
import '../data/google_calendar_sync.dart';
import '../data/tareas_repository.dart';
import 'asignaturas.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, required this.repositorio});

  final TareasRepository repositorio;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final Auth auth = Auth();
  bool _calendarSyncEnabled = false;
  bool _calendarLoading = true;
  bool _calendarBusy = false;
  String? _calendarEmail;

  @override
  void initState(){
    super.initState();
    _cargarEstadoCalendar();
  }

  /// Input:
  /// - No recibe parámetros; consulta las preferencias de Calendar.
  /// Output:
  /// - `Future<void>`: termina al actualizar el estado de conexión visible.
  /// Resumen:
  /// - Carga si la sincronización está activa y qué cuenta está vinculada.
  Future<void> _cargarEstadoCalendar() async{
    try{
      final habilitada =
          await widget.repositorio.sincronizacionCalendarHabilitada();
      final correo = await widget.repositorio.correoCalendarVinculado();
      if (!mounted) return;
      setState((){
        _calendarSyncEnabled = habilitada;
        _calendarEmail = correo;
        _calendarLoading = false;
      });
    } catch (_){
      if (!mounted) return;
      setState(() => _calendarLoading = false);
      _mostrarMensaje('No se pudo cargar el estado de Google Calendar.');
    }
  }

  /// Input:
  /// - `habilitar` (`bool`): indica si se activará o desactivará la sincronización.
  /// Output:
  /// - `Future<void>`: termina tras confirmar y actualizar la preferencia.
  /// Resumen:
  /// - Solicita confirmación y gestiona la vinculación de tareas con Calendar.
  Future<void> _cambiarSincronizacionCalendar(bool habilitar) async{
    if (_calendarBusy) return;
    if (habilitar){
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sincronizar con Google Calendar'),
          content: const Text(
            'Se solicitará permiso para crear y actualizar eventos. '
            'Las tareas existentes y las nuevas se sincronizarán como eventos '
            'de una hora en tu calendario principal. Al desactivar la '
            'sincronización, los eventos ya creados permanecerán en Calendar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;

      setState(() => _calendarBusy = true);
      try{
        final sincronizado = await GoogleCalendarSync(
          repositorio: widget.repositorio,
        ).habilitarYSincronizar();
        if (!mounted) return;
        if (sincronizado){
          await _cargarEstadoCalendar();
          if (!mounted) return;
          _mostrarMensaje('Tareas sincronizadas con Google Calendar.');
        }
      } catch (error){
        if (!mounted) return;
        final mensaje = error is GoogleCalendarSyncException
            ? error.message
            : 'No se pudo vincular Google Calendar. Inténtalo otra vez.';
        _mostrarMensaje(mensaje);
      } finally{
        if (mounted) setState(() => _calendarBusy = false);
      }
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar sincronización'),
        content: const Text(
          'Las tareas dejarán de actualizarse en Calendar. Los eventos que '
          'ya se crearon permanecerán allí.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _calendarBusy = true);
    try{
      await GoogleCalendarSync(
        repositorio: widget.repositorio,
      ).deshabilitar();
      if (!mounted) return;
      setState(() => _calendarSyncEnabled = false);
      _mostrarMensaje('Sincronización desactivada.');
    } catch (_){
      if (mounted) _mostrarMensaje('No se pudo desactivar la sincronización.');
    } finally{
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  /// Input:
  /// - `mensaje` (`String`): texto que se presentará al usuario.
  /// Output:
  /// - `void`: muestra una notificación temporal.
  /// Resumen:
  /// - Presenta un resultado o error en la pantalla de perfil.
  void _mostrarMensaje(String mensaje){
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Input:
  /// - No recibe parámetros; usa el estado de Calendar y la autenticación actual.
  /// Output:
  /// - `Future<void>`: termina al cancelar o cerrar la sesión.
  /// Resumen:
  /// - Confirma el cierre, desactiva Calendar si estaba activo y cierra sesión.
  Future<void> cerrarSesion() async{
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: Text(
            _calendarSyncEnabled
                ? 'Al cerrar sesión se desactivará la sincronización. Los '
                      'eventos que ya están en Google Calendar permanecerán allí. '
                      '¿Quieres continuar?'
                : '¿Estás seguro de que quieres cerrar sesión?',
          ),
          actions: [
            TextButton(
              onPressed: (){
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: (){
                Navigator.pop(context, true);
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar == true){
      if (_calendarSyncEnabled){
        try{
          await GoogleCalendarSync(
            repositorio: widget.repositorio,
          ).deshabilitar();
        } catch (_){
          if (mounted){
            _mostrarMensaje(
              'No se pudo desactivar Calendar; la sesión sigue abierta.',
            );
          }
          return;
        }
      }
      await auth.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Input:
  /// - No recibe parámetros; usa el contexto y repositorio de la pantalla.
  /// Output:
  /// - `void`: inicia la navegación a la lista de asignaturas.
  /// Resumen:
  /// - Abre la administración de asignaturas.
  void irAsignaturas(){
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context){
          return AsignaturasScreen(repositorio: widget.repositorio);
        },
      ),
    );
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema, usuario y navegación.
  /// Output:
  /// - `Widget`: devuelve la interfaz del perfil.
  /// Resumen:
  /// - Muestra datos de cuenta, opciones de Calendar y acciones de perfil.
  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    final usuario = FirebaseAuth.instance.currentUser;

    String nombreVisible = 'Estudiante';
    if (usuario != null &&
        usuario.displayName != null &&
        usuario.displayName!.trim().isNotEmpty){
      nombreVisible = usuario.displayName!.trim();
    }

    String correoVisible = 'Sin correo registrado';
    if (usuario != null && usuario.email != null && usuario.email!.isNotEmpty){
      correoVisible = usuario.email!;
    }

    Widget fotoPerfil;
    if (usuario != null &&
        usuario.photoURL != null &&
        usuario.photoURL!.isNotEmpty){
      fotoPerfil = CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(usuario.photoURL!),
      );
    } else {
      fotoPerfil = CircleAvatar(
        radius: 48,
        backgroundColor: tema.colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          size: 48,
          color: tema.colorScheme.onPrimaryContainer,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: fotoPerfil),
          const SizedBox(height: 16),
          Center(
            child: Text(
              nombreVisible,
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              correoVisible,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card.outlined(
            child: ListTile(
              leading: Icon(
                Icons.school_outlined,
                color: tema.colorScheme.primary,
              ),
              title: const Text(
                'Mis asignaturas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Gestionar asignaturas',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: irAsignaturas,
            ),
          ),
          const SizedBox(height: 12),
          Card.outlined(
            child: ListTile(
              leading: Icon(
                Icons.calendar_month_outlined,
                color: tema.colorScheme.primary,
              ),
              title: const Text(
                'Sincronizar con Google Calendar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _calendarLoading
                    ? 'Cargando estado...'
                    : _calendarSyncEnabled
                    ? 'Activo${_calendarEmail == null ? '' : ' · $_calendarEmail'}'
                    : 'Crear y actualizar eventos de tus tareas',
              ),
              trailing: _calendarBusy || _calendarLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _calendarSyncEnabled,
                      onChanged: (habilitar) =>
                          _cambiarSincronizacionCalendar(habilitar),
                    ),
              onTap: _calendarBusy || _calendarLoading
                  ? null
                  : () => _cambiarSincronizacionCalendar(
                      !_calendarSyncEnabled,
                    ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: cerrarSesion,
              icon: Icon(Icons.logout, color: tema.colorScheme.error),
              label: Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: tema.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
