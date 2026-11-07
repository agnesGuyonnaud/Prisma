// Widgets de Material Design 3.
import 'package:flutter/material.dart';

// Guarda la tarea grupal en Firestore.
import '../data/grupos_repository.dart';
// Lee las asignaturas locales para sugerirlas.
import '../data/tareas_repository.dart';
// Asignatura con su nombre y color.
import '../models/asignatura_model.dart';
// Grupo y TareaGrupal.
import '../models/grupo_model.dart';
// Subtarea y EstadoTarea.
import '../models/tarea_model.dart';
// Formato de la fecha límite.
import '../utils/fecha_tarea.dart';

class TareaGrupalFormulario extends StatefulWidget{
  const TareaGrupalFormulario({
    super.key,
    required this.grupos,
    required this.repositorio,
    this.gruposRepositorio,
    this.tarea,
    this.grupoInicial,
  });

  final List<Grupo> grupos;
  final TareasRepository repositorio;
  final GruposRepository? gruposRepositorio;
  final TareaGrupal? tarea;
  final String? grupoInicial;

  @override
  State<TareaGrupalFormulario> createState() => _TareaGrupalFormularioState();
}

class _TareaGrupalFormularioState extends State<TareaGrupalFormulario>{
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _asignatura;
  String? _grupo;
  String? _errorAsignatura;
  late DateTime _fecha;
  late final List<_SubtareaEditable> _subtareas;
  List<Asignatura> _asignaturas = [];
  bool _guardando = false;

  @override
  void initState(){
    super.initState();
    final tarea = widget.tarea;
    final hoy = DateTime.now();
    _titulo = TextEditingController(text: tarea?.titulo ?? '');
    _asignatura = TextEditingController(text: tarea?.asignatura ?? '');
    _grupo = tarea?.grupo ?? widget.grupoInicial;
    if(_grupo == null && widget.grupos.length == 1){
      _grupo = widget.grupos.first.codigo;
    }
    _fecha =
        tarea?.fechaLimite ??
        DateTime(hoy.year, hoy.month, hoy.day + 1, 23, 59);
    _subtareas = [
      for(final subtarea in tarea?.subtareas ?? <Subtarea>[])
        _SubtareaEditable(subtarea.titulo, completada: subtarea.completada),
    ];
    _cargarAsignaturas();
  }

  /// Input:
  /// - No recibe parámetros; consulta el repositorio local.
  /// Output:
  /// - `Future<void>`: termina al actualizar la lista de asignaturas.
  /// Resumen:
  /// - Carga las asignaturas para sugerirlas en el selector.
  Future<void> _cargarAsignaturas() async{
    final lista = await widget.repositorio.listarAsignaturas();
    if(!mounted) return;
    setState(() => _asignaturas = lista);
  }

  @override
  void dispose(){
    _titulo.dispose();
    _asignatura.dispose();
    super.dispose();
  }

  /// Input:
  /// - `valor` (`String?`): contenido del campo que se validará.
  /// Output:
  /// - `String?`: mensaje si está vacío o `null` si tiene contenido.
  /// Resumen:
  /// - Valida que el campo obligatorio contenga texto.
  String? _obligatorio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Completa este campo' : null;

  /// Input:
  /// - No recibe parámetros; usa la fecha y hora límite actuales.
  /// Output:
  /// - `Future<void>`: termina al seleccionar o cancelar fecha y hora.
  /// Resumen:
  /// - Permite elegir la fecha y hora límite de la tarea.
  Future<void> _elegirFecha() async{
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha límite',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );
    if(fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
      helpText: 'Hora límite',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if(hora == null || !mounted) return;
    setState(
      () => _fecha = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  /// Input:
  /// - No recibe parámetros; obtiene los valores de los controles.
  /// Output:
  /// - `Future<void>`: termina al guardar la tarea o informar un error.
  /// Resumen:
  /// - Valida el formulario, guarda la tarea en el grupo y vuelve atrás.
  Future<void> _guardar() async{
    if(_guardando) return;
    final asignatura = _asignatura.text.trim();
    final valido = _formulario.currentState!.validate();
    setState(
      () => _errorAsignatura = asignatura.isEmpty ? 'Completa este campo' : null,
    );
    if(!valido || asignatura.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    final tarea = TareaGrupal(
      id: widget.tarea?.id,
      grupo: _grupo!,
      titulo: _titulo.text.trim(),
      asignatura: asignatura,
      fechaLimite: _fecha,
      estado: widget.tarea?.estado ?? EstadoTarea.pendiente,
      subtareas: [
        for(final subtarea in _subtareas)
          Subtarea(
            titulo: subtarea.titulo.trim(),
            completada: subtarea.completada,
          ),
      ],
      documentos: widget.tarea?.documentos ?? const [],
      notas: widget.tarea?.notas ?? const [],
    );
    try{
      final guardada =
          await (widget.gruposRepositorio ?? GruposRepository.instancia)
              .guardarTarea(tarea);
      if(!mounted) return;
      Navigator.of(context).pop(guardada);
    } catch(_){
      if(!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar la tarea. Revisa tu conexión e inténtalo otra vez.',
          ),
        ),
      );
    }
  }

  /// Input:
  /// - `context` (`BuildContext`): contexto para tema, validación y navegación.
  /// Output:
  /// - `Widget`: formulario de creación o edición de tarea grupal.
  /// Resumen:
  /// - Construye los campos de grupo, título, asignatura, fecha y subtareas.
  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    final editando = widget.tarea != null;

    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editando ? 'Editar tarea grupal' : 'Nueva tarea grupal'),
          centerTitle: false,
          titleSpacing: 16,
          leading: IconButton(
            tooltip: 'Volver',
            icon: const BackButtonIcon(),
            onPressed: _guardando
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formulario,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _grupo,
                  isExpanded: true,
                  hint: const Text('Selecciona un grupo'),
                  decoration: InputDecoration(
                    labelText: 'Grupo',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.groups_outlined),
                    helperText: editando
                        ? 'Una tarea no se puede mover a otro grupo.'
                        : 'Todos los integrantes verán esta tarea.',
                  ),
                  items: [
                    for(final grupo in widget.grupos)
                      DropdownMenuItem(
                        value: grupo.codigo,
                        child: Text(grupo.nombre),
                      ),
                  ],
                  onChanged: _guardando || editando
                      ? null
                      : (valor) => setState(() => _grupo = valor),
                  validator: _obligatorio,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titulo,
                  enabled: !_guardando,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  validator: _obligatorio,
                ),
                const SizedBox(height: 16),
                DropdownMenu<String>(
                  controller: _asignatura,
                  enabled: !_guardando,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  label: const Text('Asignatura'),
                  errorText: _errorAsignatura,
                  helperText: 'Elige una de tus asignaturas o escribe otra.',
                  onSelected: (_) => setState(() => _errorAsignatura = null),
                  dropdownMenuEntries: [
                    for(final asignatura in _asignaturas)
                      DropdownMenuEntry(
                        value: asignatura.nombre,
                        label: asignatura.nombre,
                        leadingIcon: CircleAvatar(
                          backgroundColor: asignatura.color,
                          radius: 6,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card.filled(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Fecha límite'),
                    subtitle: Text(fechaTarea(_fecha)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _guardando ? null : _elegirFecha,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Subtareas', style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                if(_subtareas.isEmpty)
                  const Text(
                    'Divide el trabajo en subtareas para que cada integrante marque lo que termina.',
                  ),
                for(final subtarea in _subtareas)
                  Padding(
                    key: ObjectKey(subtarea),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: subtarea.titulo,
                            enabled: !_guardando,
                            decoration: const InputDecoration(
                              labelText: 'Subtarea',
                              border: OutlineInputBorder(),
                            ),
                            maxLength: 120,
                            validator: _obligatorio,
                            onChanged: (valor) => subtarea.titulo = valor,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar subtarea',
                          onPressed: _guardando
                              ? null
                              : () =>
                                    setState(() => _subtareas.remove(subtarea)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => setState(
                            () => _subtareas.add(_SubtareaEditable('')),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir subtarea'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_guardando ? 'Guardando…' : 'Guardar tarea'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtareaEditable{
  _SubtareaEditable(this.titulo, {this.completada = false});
  String titulo;
  final bool completada;
}
