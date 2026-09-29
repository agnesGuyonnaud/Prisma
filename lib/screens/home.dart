import 'package:flutter/material.dart';

import '../widgets/tarea_mini.dart';
import 'tarea.dart';

/// Home provisional para mostrar la tarjeta y abrir su vista de detalle.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        // Un único margen exterior de 16 dp alinea el saludo, el perfil y
        // las tareas, también cuando la ventana supera los 600 dp de ancho.
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            // Permite desplazar la última tarjeta por encima del FAB.
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hola, estudiante',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Indicador de perfil decorativo, sin acción.
                  Semantics(
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
                ],
              ),
              const SizedBox(height: 32),
              Text('Tareas', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              // Solo texto de referencia: todavía no abre una lista.
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver todas las tareas →',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // El home define la navegación; la tarjeta es reutilizable.
              // push conserva esta pantalla para regresar con Atrás.
              TareaMini(
                titulo: 'Tarea 1',
                asignatura: 'Aplicaciones móviles',
                fechaLimite: '30 sep 2026 · 23:59',
                tipo: 'Proyecto',
                totalSubtareas: 3,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const TareaScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // Botón flotante sobre la barra inferior; sigue sin acción por ahora.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        icon: const Icon(Icons.add),
        label: const Text('Añadir tarea'),
      ),
      // endFloat ya aporta 16 dp desde el borde seguro: no duplicar el margen.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Barra de referencia visual: Inicio permanece seleccionado.
      // Sin onDestinationSelected, las opciones no cambian la vista ni la selección.
      // El fondo llega al borde; el contenido conserva 16 dp a cada lado.
      bottomNavigationBar: ColoredBox(
        color: colores.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NavigationBar(
            backgroundColor: colores.surfaceContainer,
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
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
                label: 'Grupos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
