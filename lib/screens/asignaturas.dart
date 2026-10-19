import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/asignatura_model.dart';

class AsignaturasScreen extends StatefulWidget{
  const AsignaturasScreen({super.key, required this.repositorio});

  final TareasRepository repositorio;

  @override
  State<AsignaturasScreen> createState() => _AsignaturasScreenState();
}

class _AsignaturasScreenState extends State<AsignaturasScreen>{
  List<Asignatura> listaAsignaturas = [];
  bool cargando = true;

  @override
  void initState(){
    super.initState();
    cargarAsignaturas();
  }

  Future<void> cargarAsignaturas() async{
    setState((){
      cargando = true;
    });
    List<Asignatura> resultado = await widget.repositorio.listarAsignaturas();
    if (!mounted) return;
    setState((){
      listaAsignaturas = resultado;
      cargando = false;
    });
  }

  Future<void> crearAsignatura() async{
    Asignatura? guardada = await mostrarDialogoAsignatura(
      context: context,
      repositorio: widget.repositorio,
    );
    if (guardada != null){
      cargarAsignaturas();
    }
  }

  Future<void> editarAsignatura(Asignatura asignatura) async{
    Asignatura? guardada = await mostrarDialogoAsignatura(
      context: context,
      repositorio: widget.repositorio,
      asignatura: asignatura,
    );
    if (guardada != null){
      cargarAsignaturas();
    }
  }

  Future<void> borrarAsignatura(Asignatura asignatura) async{
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text('¿Eliminar asignatura?'),
          content: Text('Se va a eliminar "${asignatura.nombre}".'),
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
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && asignatura.id != null){
      await widget.repositorio.eliminarAsignatura(asignatura.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminó ${asignatura.nombre}')),
      );
      cargarAsignaturas();
    }
  }

  @override
  Widget build(BuildContext context){
    if (cargando){
      return Scaffold(
        appBar: AppBar(title: const Text('Mis asignaturas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (listaAsignaturas.isEmpty){
      return Scaffold(
        appBar: AppBar(title: const Text('Mis asignaturas')),
        body: const Center(
          child: Text(
            'No tienes asignaturas guardadas.\nPulsa el botón + para añadir una.',
            textAlign: TextAlign.center,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: crearAsignatura,
          icon: const Icon(Icons.add),
          label: const Text('Nueva asignatura'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis asignaturas')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: listaAsignaturas.length,
        itemBuilder: (BuildContext context, int index){
          Asignatura item = listaAsignaturas[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: item.color, radius: 16),
              title: Text(
                item.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: (){
                      editarAsignatura(item);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: (){
                      borrarAsignatura(item);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: crearAsignatura,
        icon: const Icon(Icons.add),
        label: const Text('Nueva asignatura'),
      ),
    );
  }
}

Future<Asignatura?> mostrarDialogoAsignatura({
  required BuildContext context,
  required TareasRepository repositorio,
  Asignatura? asignatura,
}){
  return showDialog<Asignatura>(
    context: context,
    builder: (BuildContext context){
      return _DialogoAsignatura(
        repositorio: repositorio,
        asignatura: asignatura,
      );
    },
  );
}

class _DialogoAsignatura extends StatefulWidget{
  const _DialogoAsignatura({required this.repositorio, this.asignatura});

  final TareasRepository repositorio;
  final Asignatura? asignatura;

  @override
  State<_DialogoAsignatura> createState() => _DialogoAsignaturaState();
}

class _DialogoAsignaturaState extends State<_DialogoAsignatura>{
  final TextEditingController textoNombre = TextEditingController();
  Color colorElegido = const Color(0xFF4CAF50);
  String? mensajeError;

  final List<Color> listaColores = const [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF009688),
    Color(0xFFF44336),
    Color(0xFFFFC107),
  ];

  @override
  void initState(){
    super.initState();
    if (widget.asignatura != null){
      textoNombre.text = widget.asignatura!.nombre;
      colorElegido = widget.asignatura!.color;
    }
  }

  @override
  void dispose(){
    textoNombre.dispose();
    super.dispose();
  }

  Future<void> guardar() async{
    String nombre = textoNombre.text.trim();
    if (nombre.isEmpty){
      setState((){
        mensajeError = 'Escribe un nombre para la asignatura';
      });
      return;
    }

    try{
      Asignatura nueva = Asignatura(
        id: widget.asignatura?.id,
        nombre: nombre,
        color: colorElegido,
      );
      Asignatura guardada = await widget.repositorio.guardarAsignatura(nueva);
      if (!mounted) return;
      Navigator.pop(context, guardada);
    }
    
    catch (e){
      setState((){
        mensajeError = 'Ocurrió un error al guardar';
      });
    }
  }

  @override
  Widget build(BuildContext context){
    bool esEdicion = widget.asignatura != null;

    return AlertDialog(
      title: Text(esEdicion ? 'Editar asignatura' : 'Nueva asignatura'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textoNombre,
              decoration: InputDecoration(
                labelText: 'Nombre de la asignatura',
                hintText: 'Ej: Cálculo 1',
                errorText: mensajeError,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            const Text(
              'Color de la asignatura:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int i = 0; i < listaColores.length; i++)
                  GestureDetector(
                    onTap: (){
                      setState((){
                        colorElegido = listaColores[i];
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: listaColores[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorElegido == listaColores[i]
                              ? Colors.black
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: colorElegido == listaColores[i]
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (){
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: guardar, child: const Text('Guardar')),
      ],
    );
  }
}
