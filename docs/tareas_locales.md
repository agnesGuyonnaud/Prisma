# Tareas locales

El botón **Añadir tarea** abre el formulario. Al guardar, la tarea se escribe en
SQLite y aparece en el home. Tocar su tarjeta abre el detalle. Desde allí se puede
editar, cambiar el estado, marcar subtareas y eliminar con confirmación.

## Archivos

- `lib/models/tarea_model.dart`: datos de tarea y subtarea, importancia y estado.
- `lib/data/tareas_repository.dart`: apertura de SQLite y operaciones de lectura,
  guardado y eliminación. Comparte una conexión mediante `instancia`.
- `lib/screens/tarea_formulario.dart`: creación y edición con validación.
- `lib/screens/home.dart`: consulta las tareas y actualiza la lista al regresar.
- `lib/screens/tarea.dart`: detalle y acciones sobre la tarea seleccionada.
- `lib/widgets/tarea_mini.dart`: presentación de cada tarjeta, sin acceso a SQLite.

## Integración con las otras partes del proyecto

La asignatura se elige de una lista provisional: Matemáticas, Estructuras de datos
y Física. Al editar se conserva también cualquier asignatura antigua. Se sigue
guardando su nombre como texto; más adelante se podrá vincular con el identificador
del módulo de asignaturas, lo que requerirá una migración de la base de datos.

El repositorio guarda en `prisma_tareas.db`, dentro del directorio privado de bases
de datos de la aplicación. No se solicitan permisos de almacenamiento compartido.
La tabla `tareas` contiene todos los campos de la tarea y sus subtareas en JSON;
una escritura guarda el conjunto de forma atómica. El esquema tiene versión 2.
La importancia se guarda como entero entre 1 y 5 (3 por defecto). Se elige con
un slider en el formulario o en el detalle; en el detalle se guarda al soltarlo.
La migración desde la versión 1 convierte baja → 1, media → 3 y alta → 5,
conservando los identificadores y los demás datos de las tareas.
No hay que eliminar el archivo para actualizar la app: futuros cambios del esquema
deben aumentar la versión y añadir una migración.

El home lista todas las tareas por fecha límite, incluidas las completadas.
La prioridad automática, las asignaturas, el perfil, las otras pestañas y Google
Calendar quedan para sus respectivos módulos. La barra inferior sigue siendo visual.

## Ejecutar y comprobar

Este flujo usa `sqflite` en Android/iOS. Después de añadir un plugin nativo, detener
la ejecución anterior y ejecutar de nuevo con `flutter run`; Hot Reload no basta
para registrar el plugin.

```sh
flutter pub get
flutter analyze
flutter test test/tareas_repository_test.dart test/tareas_formulario_test.dart
flutter test integration_test/tareas_locales_test.dart -d emulator-5554
```

La prueba de integración usa una base temporal distinta a la del usuario. Las
pruebas de repositorio usan SQLite real mediante `sqflite_common_ffi`, solo como
dependencia de desarrollo.

`test/widget_test.dart` se conservó para el compañero que lo mantiene. Su prueba
antigua todavía espera abrir directamente el detalle y encontrar Eliminar fuera
del menú; debe actualizarse antes de ejecutar toda la suite con `flutter test`.
