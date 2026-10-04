// Sipi — widgets compartidos.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/social_labels.dart';
import '../core/api.dart';
import '../core/session.dart';

/// Botón principal estilo clay: pieza esponjosa con doble sombra y
/// animación de "hundido" al presionarlo.
class SipiButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  const SipiButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color = SipiColors.primary,
  });

  @override
  State<SipiButton> createState() => _SipiButtonState();
}

class _SipiButtonState extends State<SipiButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final color = enabled ? widget.color : SipiColors.muted.withValues(alpha: 0.55);
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: 56,
          alignment: Alignment.center,
          decoration: _pressed
              ? Clay.pressed(color: color, radius: SipiRadii.md)
              : Clay.button(color, radius: SipiRadii.md),
          child: widget.loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
        ),
      ),
    );
  }
}

class PointsPill extends StatelessWidget {
  final int points;
  const PointsPill({super.key, required this.points});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SipiColors.successSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('+$points pts',
          style: const TextStyle(
              color: SipiColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 12)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SipiColors.text)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: SipiColors.primary,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(64, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

IconData taskIcon(String category) {
  switch (category) {
    case 'social':
      return Icons.share_outlined;
    case 'encuestas':
    case 'opinion':
      return Icons.poll_outlined;
    case 'productos':
      return Icons.shopping_bag_outlined;
    case 'promociones':
      return Icons.local_offer_outlined;
    default:
      return Icons.task_alt_outlined;
  }
}

Color taskIconBg(String category) {
  switch (category) {
    case 'social':
      return SipiColors.pink;
    case 'encuestas':
      return SipiColors.warning;
    case 'opinion':
      return SipiColors.danger;
    case 'productos':
      return SipiColors.primary;
    case 'promociones':
      return SipiColors.success;
    default:
      return SipiColors.muted;
  }
}

Color categoryColor(String category) => taskIconBg(category);

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = categoryColor(task.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: Clay.card(),
      child: InkWell(
        borderRadius: BorderRadius.circular(SipiRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TaskThumb(task: task),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: SipiColors.text,
                            height: 1.25)),
                    if (task.isSocial) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(socialNetworkIcon(task.socialNetwork),
                            size: 13, color: SipiColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              '${socialActionText(task.socialAction, task.socialNetwork)} · pide tu usuario',
                              style: const TextStyle(
                                  color: SipiColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(CategoryMeta.label(task.category),
                            style: TextStyle(
                                color: bg,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.schedule_outlined,
                          size: 13, color: SipiColors.muted),
                      const SizedBox(width: 3),
                      Text('${task.estimatedMinutes} min',
                          style: const TextStyle(
                              color: SipiColors.muted, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PointsPill(points: task.points),
                  const SizedBox(height: 6),
                  const Icon(Icons.arrow_forward_ios,
                      color: SipiColors.muted, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura de la tarea: muestra la imagen elegida en el panel
/// (logo de red social o URL personalizada) o el icono de la categoría.
class TaskThumb extends StatelessWidget {
  final Task task;
  const TaskThumb({required this.task});

  @override
  Widget build(BuildContext context) {
    if (task.imageUrl.isNotEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: Clay.shadows(depth: 4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            task.imageUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconThumb(),
          ),
        ),
      );
    }
    return _iconThumb();
  }

  Widget _iconThumb() {
    final bg = taskIconBg(task.category);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          boxShadow: Clay.shadows(depth: 4)),
      child: Icon(taskIcon(task.category), color: bg, size: 24),
    );
  }
}

class BalanceCard extends StatelessWidget {
  final int points;
  final double usd;
  final int pointsPerUsd;
  const BalanceCard(
      {super.key,
      required this.points,
      required this.usd,
      required this.pointsPerUsd});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SipiColors.primaryDark,
        borderRadius: BorderRadius.circular(SipiRadii.xl),
        boxShadow: [
          BoxShadow(
            color: SipiColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.stars_outlined, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text('Tus puntos',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text(_fmt(points),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(
                  'Te faltan ${pointsPerUsd - (points % pointsPerUsd)} pts para canjear \$1.00',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(SipiRadii.md),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Equivale a',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('\$${usd.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ]),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

Future<void> showError(BuildContext context, Object e) {
  final msg = e is ApiException
      ? ApiException.friendly(e.code)
      : 'Ocurrió un error. Inténtalo de nuevo.';
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Ups'),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('OK'))
      ],
    ),
  );
}

/// Puerta de invitado: si no hay cuenta, muestra el diálogo para crear una
/// y devuelve false. Úsalo al inicio de cualquier acción interactiva.
/// Si devuelve true, el llamador debe navegar a RegisterScreen.
Future<bool> ensureAccount(BuildContext context, Session session) async {
  if (session.canInteract) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Crea tu cuenta',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: const Text(
          'Estás explorando como invitado. Para ganar puntos y canjear '
          'recompensas necesitas crear una cuenta. Es gratis.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear cuenta')),
      ],
    ),
  );
  return go == true;
}

/// Pantalla completa para secciones que requieren cuenta (canjear, logros).
class GuestGateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCreateAccount;
  const GuestGateCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onCreateAccount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration:
                    Clay.circle(SipiColors.primarySoft, depth: 7),
                child: const Icon(Icons.person_add_alt_outlined,
                    color: SipiColors.primary, size: 40),
              ),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: SipiColors.muted, fontSize: 15, height: 1.5)),
              const SizedBox(height: 24),
              SipiButton(
                label: 'Crear cuenta',
                onPressed: onCreateAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 92,
            height: 92,
            decoration:
                Clay.circle(SipiColors.primarySoft, depth: 7),
            child: Icon(icon, size: 40, color: SipiColors.primary),
          ),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: SipiColors.muted, fontSize: 14, height: 1.4)),
        ]),
      ),
    );
  }
}
