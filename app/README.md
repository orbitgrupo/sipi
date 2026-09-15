# Sipi — App móvil (Flutter)

App de recompensas por tareas: gana puntos completando tareas y canjéalos por dinero.

## Requisitos

- Flutter SDK 3.4+
- Backend corriendo (`../backend`: `npm start` en `http://localhost:3000`)

## Correr

```bash
flutter pub get
flutter run
```

La app apunta por defecto a `http://10.0.2.2:3000` (localhost desde el emulador
Android). Para un dispositivo físico o iOS, cambia `baseUrl` en
`lib/core/api.dart` por la IP de tu máquina.

## Estructura

```
lib/
  main.dart            # entrada: Welcome ↔ MainShell según sesión
  core/
    theme.dart         # colores y estilos (mockup)
    models.dart        # modelos espejo de la API
    api.dart           # cliente HTTP (el servidor calcula los montos)
    session.dart       # sesión: usuario, token, saldo
  widgets/
    common.dart        # botones, tarjetas, pills, estados vacíos
  screens/
    welcome_auth.dart  # bienvenida, registro, login
    home.dart          # shell + bottom nav + inicio
    tasks.dart         # lista, detalle y éxito de tarea
    surveys.dart       # lista y respuesta de encuestas
    redeem.dart        # canjear + historial de pagos
    achievements.dart  # nivel e insignias
    profile.dart       # perfil, historial de puntos, notificaciones,
                       # soporte, configuración, más, pantalla final
```

## Pantallas (mockup)

Bienvenida · Registro · Inicio de sesión · Inicio · Tareas · Detalle de
tarea · Verificación · Encuestas · Canjear recompensas · Historial de pagos ·
Puntos y logros · Perfil · Notificaciones · Soporte · Configuración ·
Más/Menú · Pantalla final.
