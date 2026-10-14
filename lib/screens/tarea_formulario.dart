import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/asignatura_model.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';
import '../widgets/importancia_slider.dart';
import 'asignaturas.dart';

class TareaFormulario extends StatefulWidget {
  const TareaFormulario({super.key, required this.repositorio, this.tarea});

  final TareasRepository repositorio;
  final Tarea? tarea;

  @override
  State<TareaFormulario> createState() => _TareaFormularioState();
}

class _TareaFormularioState extends State<TareaFormulario> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  String? _asignatura;
  late DateTime _fecha;
  late String _tipo;
  late int _importancia;
  late EstadoTarea _estado;
  late final List<_SubtareaEditable> _subtareas;
  bool _guardando = false;

  List<Asignatura> _asignaturas = [];

  static const _tipos = [
    'Tarea',
    'Proyecto',
    'Prueba',
    'Examen',
    'Laboratorio',
    'Presentación',
    'Lectura',
    'Otro',
  ];

  @override
  void initState(){
    super.initState();
    final tarea = widget.tarea;
    final hoy = DateTime.now();
    _titulo = TextEditingController(text: tarea?.titulo ?? '');
    _asignatura = tarea?.asignatura;
    _fecha =
        tarea?.fechaLimite ??
        DateTime(hoy.year, hoy.month, hoy.day + 1, 23, 59);
    _tipo = tarea?.tipo ?? 'Tarea';
    _importancia = tarea?.importancia ?? 3;
    _estado = tarea?.estado ?? EstadoTarea.pendiente;
    _subtareas = [
      for (final subtarea in tarea?.subtareas ?? <Subtarea>[])
        _SubtareaEditable(subtarea.titulo, completada: subtarea.completada),
    ];

    _cargarAsignaturas();
  }

  Future<void> _cargarAsignaturas() async{
    final lista = await widget.repositorio.listarAsignaturas();
    if (!mounted) return;
    setState((){
      _asignaturas = lista;
    });
  }

  Future<void> _crearAsignaturaRapida() async{
    final nueva = await mostrarDialogoAsignatura(
      context: context,
      repositorio: widget.repositorio,
    );
    if (nueva != null){
      await _cargarAsignaturas();
      if (!mounted) return;
      setState((){
        _asignatura = nueva.nombre;
      });
    }
  }

  @override
  void dispose(){
    _titulo.dispose();
    super.dispose();
  }

  String? _obligatorio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Completa este campo' : null;

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
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
      helpText: 'Hora límite',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (hora == null || !mounted) return;
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

  Future<void> _guardar() async{
    if (_guardando || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    final tarea = Tarea(
      id: widget.tarea?.id,
      titulo: _titulo.text.trim(),
      asignatura: _asignatura!,
      fechaLimite: _fecha,
      tipo: _tipo,
      importancia: _importancia,
      estado: _estado,
      subtareas: [
        for (final subtarea in _subtareas)
          Subtarea(
            titulo: subtarea.titulo.trim(),
            completada: subtarea.completada,
          ),
      ],
    );
    try{
      final guardada = await widget.repositorio.guardar(tarea);
      if (!mounted) return;
      Navigator.of(context).pop(guardada);
    } catch (_){
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar la tarea. Tus datos siguen aquí; inténtalo otra vez.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context){
    final tema = Theme.of(context);
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tarea == null ? 'Añadir tarea' : 'Editar tarea'),
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
                DropdownButtonFormField<String>(
                  key: ValueKey('asignatura_$_asignatura'),
                  initialValue: _asignatura,
                  isExpanded: true,
                  hint: const Text('Selecciona una asignatura'),
                  decoration: InputDecoration(
                    labelText: 'Asignatura',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Nueva asignatura',
                      onPressed: _guardando ? null : _crearAsignaturaRapida,
                    ),
                  ),
                  items: [
                    for (final a in _asignaturas)
                      DropdownMenuItem<String>(
                        value: a.nombre,
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: a.color, radius: 6),
                            const SizedBox(width: 8),
                            Text(a.nombre),
                          ],
                        ),
                      ),

                    if (widget.tarea != null &&
                        !_asignaturas.any(
                          (a) => a.nombre == widget.tarea!.asignatura,
                        ))
                      DropdownMenuItem<String>(
                        value: widget.tarea!.asignatura,
                        child: Text(widget.tarea!.asignatura),
                      ),

                    const DropdownMenuItem<String>(
                      value: '__NUEVA_ASIGNATURA__',
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '+ Nueva asignatura',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor){
                          if (valor == '__NUEVA_ASIGNATURA__'){
                            _crearAsignaturaRapida();
                          } 
                          
                          else {
                            setState(() => _asignatura = valor);
                          }
                        },
                  validator: _obligatorio,
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final tipo in {..._tipos, _tipo})
                      DropdownMenuItem(value: tipo, child: Text(tipo)),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _tipo = valor!),
                ),
                const SizedBox(height: 16),
                ImportanciaSlider(
                  valor: _importancia,
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _importancia = valor),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EstadoTarea>(
                  initialValue: _estado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final estado in EstadoTarea.values)
                      DropdownMenuItem(
                        value: estado,
                        child: Text(estado.etiqueta),
                      ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _estado = valor!),
                ),
                const SizedBox(height: 24),
                Text('Subtareas', style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_subtareas.isEmpty)
                  const Text(
                    'Puedes añadir subtareas para dividir el trabajo.',
                  ),
                for (final subtarea in _subtareas)
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
