import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../utils/fecha_tarea.dart';

/// El mismo formulario sirve para crear una tarea y editar una ya guardada.
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
  late ImportanciaTarea _importancia;
  late EstadoTarea _estado;
  late final List<_SubtareaEditable> _subtareas;
  bool _guardando = false;

  // Opciones provisionales hasta conectar el módulo de asignaturas.
  static const _asignaturas = ['Matemáticas', 'Estructuras de datos', 'Física'];

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
  void initState() {
    super.initState();
    final tarea = widget.tarea;
    final hoy = DateTime.now();
    _titulo = TextEditingController(text: tarea?.titulo ?? '');
    _asignatura = tarea?.asignatura;
    _fecha =
        tarea?.fechaLimite ??
        DateTime(hoy.year, hoy.month, hoy.day + 1, 23, 59);
    _tipo = tarea?.tipo ?? 'Tarea';
    _importancia = tarea?.importancia ?? ImportanciaTarea.media;
    _estado = tarea?.estado ?? EstadoTarea.pendiente;
    _subtareas = [
      for (final subtarea in tarea?.subtareas ?? <Subtarea>[])
        _SubtareaEditable(subtarea.titulo, completada: subtarea.completada),
    ];
  }

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  String? _obligatorio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Completa este campo' : null;

  Future<void> _elegirFecha() async {
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
    // Cancelar cualquiera de los selectores conserva la fecha anterior.
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

  Future<void> _guardar() async {
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
    try {
      // Se vuelve a la pantalla anterior solo después de confirmar la escritura.
      final guardada = await widget.repositorio.guardar(tarea);
      if (!mounted) return;
      Navigator.of(context).pop(guardada);
    } catch (_) {
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
  Widget build(BuildContext context) {
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
                  key: const ValueKey('asignatura'),
                  initialValue: _asignatura,
                  isExpanded: true,
                  hint: const Text('Selecciona una asignatura'),
                  decoration: const InputDecoration(
                    labelText: 'Asignatura',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    // Al editar, conserva también cualquier asignatura antigua
                    // que no forme parte de estas tres opciones de ejemplo.
                    for (final asignatura in {
                      ..._asignaturas,
                      if (widget.tarea != null) widget.tarea!.asignatura,
                    })
                      DropdownMenuItem(
                        value: asignatura,
                        child: Text(asignatura),
                      ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _asignatura = valor),
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
                DropdownButtonFormField<ImportanciaTarea>(
                  initialValue: _importancia,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Importancia',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final importancia in ImportanciaTarea.values)
                      DropdownMenuItem(
                        value: importancia,
                        child: Text(importancia.etiqueta),
                      ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _importancia = valor!),
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

// Borrador con identidad estable: quitar una fila no intercambia sus textos.
class _SubtareaEditable {
  _SubtareaEditable(this.titulo, {this.completada = false});
  String titulo;
  final bool completada;
}
