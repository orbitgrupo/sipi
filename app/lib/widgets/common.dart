// Sipi — widgets compartidos.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/api.dart';

class SipiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const SipiButton(
      {super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
          : Text(label),
    );
  }
}

class PointsPill extends StatelessWidget {
  final int points;
  const PointsPill({super.key, required this.points});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SipiColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('+$points pts',
          style: const TextStyle(
              color: SipiColors.primary,
              fontWeight: FontWeight.w700,
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
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: SipiColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
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
      return const Color(0xFFE1306C);
    case 'encuestas':
      return const Color(0xFFF5A623);
    case 'opinion':
      return const Color(0xFFE5484D);
    case 'productos':
      return const Color(0xFF2456E6);
    case 'promociones':
      return const Color(0xFF22B573);
    default:
      return const Color(0xFF8A93B2);
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = taskIconBg(task.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: bg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(taskIcon(task.category), color: bg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: SipiColors.text)),
                    const SizedBox(height: 3),
                    Text(
                        '${CategoryMeta.label(task.category)} · ${task.estimatedMinutes} min',
                        style: const TextStyle(
                            color: SipiColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              PointsPill(points: task.points),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: SipiColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  final int points;
  final double usd;
  const BalanceCard({super.key, required this.points, required this.usd});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SipiColors.primary, SipiColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tus puntos',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('$_fmt(points)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Te faltan ${100 - (points % 100)} pts para canjear \$1.00',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Equivalente a',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('\$${usd.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ]),
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
          Icon(icon, size: 56, color: SipiColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SipiColors.muted)),
        ]),
      ),
    );
  }
}
