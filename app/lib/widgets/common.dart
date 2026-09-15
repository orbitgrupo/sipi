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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SipiRadii.lg),
        border: Border.all(color: SipiColors.border),
        boxShadow: SipiShadows.soft,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SipiRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        bg.withValues(alpha: 0.16),
                        bg.withValues(alpha: 0.08)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(SipiRadii.md)),
                child: Icon(taskIcon(task.category), color: bg, size: 22),
              ),
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

class BalanceCard extends StatelessWidget {
  final int points;
  final double usd;
  const BalanceCard({super.key, required this.points, required this.usd});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F63F0), SipiColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SipiRadii.xl),
        boxShadow: [
          BoxShadow(
            color: SipiColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Adornos decorativos.
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -55,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius:
                                BorderRadius.circular(SipiRadii.sm),
                          ),
                          child: const Icon(Icons.stars_outlined,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Tus puntos',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      Text(_fmt(points),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text(
                          'Te faltan ${100 - (points % 100)} pts para canjear \$1.00',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5)),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(SipiRadii.md),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Equivale a',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('\$${usd.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
            ],
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
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: SipiColors.primarySoft,
              borderRadius: BorderRadius.circular(SipiRadii.xl),
            ),
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
