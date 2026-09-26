# Sipi — Sistema de diseño

Paleta y tipografía compartidas por la app móvil y el panel web.
La fuente de verdad para la app es `app/lib/core/theme.dart` (`SipiColors`).

## Colores (app — `SipiColors`)

| Nombre | Hex | Uso |
|---|---|---|
| `primary` | `#2456E6` | Botones, enlaces, acentos principales |
| `primaryLight` | `#2F63F0` | Gradientes, estados activos |
| `primaryDark` | `#1A3FB8` | Gradientes oscuros |
| `primarySoft` | `#E8EDFD` | Fondos suaves destacados |
| `accent` | `#7C5CFF` | Logros, encuestas (morado) |
| `accentLight` | `#9D7BFF` | Gradientes de logros |
| `accentDark` | `#4A2FD6` | Gradientes de logros |
| `background` | `#F4F6FB` | Fondo de pantallas |
| `text` | `#1B2340` | Texto principal |
| `muted` | `#8A93B2` | Texto secundario |
| `border` | `#E6EAF3` | Bordes y divisores |
| `success` | `#22B573` | Completado, aprobado |
| `successSoft` | `#E2F6EC` | Fondos de éxito |
| `warning` | `#F5A623` | Acentos ámbar |
| `warningDark` | `#B45309` | Texto "Pendiente" (contraste accesible) |
| `warningSoft` | `#FDF1DC` | Fondos de aviso |
| `danger` | `#E5484D` | Rechazado, errores, cerrar sesión |
| `dangerSoft` | `#FBE4E5` | Fondos de error |
| `gold` | `#FFD54F` | Pantalla de agradecimiento |
| `pink` | `#E1306C` | Categoría Redes sociales |

> Regla: ningún color va hardcodeado en las pantallas; todo pasa por
> `SipiColors`. El texto sobre fondos ámbar usa `warningDark`, no `warning`.

## Panel web

- Sidebar navy oscuro (`#0C1526` → `#1E2F5E`), píldora activa en degradado azul.
- Tarjetas blancas con barra de acento en degradado e iconos con brillo.
- Gráficas en SVG puro (sin dependencias): área de actividad 30 días y dona
  de tipos de tareas con reparto por resto mayor (la leyenda suma 100%).
- Fuente del sistema; títulos con subrayado degradado.

## Tipografía

- App: fuente del sistema, pesos 600–900 para títulos, 13–16 px para cuerpo.
- Panel: fuente del sistema (línea Nunito en versiones anteriores), títulos
  20–24 px con subrayado degradado.

## Iconografía

- App: Material Icons.
- Panel: iconos SVG inline (estilo Feather), sin dependencias externas.
