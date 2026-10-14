import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth.dart';
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

  Future<void> cerrarSesion() async{
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
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
      await auth.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

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
