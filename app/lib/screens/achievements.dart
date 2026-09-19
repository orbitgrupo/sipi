// Sipi — Mis logros: nivel, progreso e insignias (pantalla 11 del mockup).
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';

const _levelNames = {
  1: 'Novato',
  2: 'Aprendiz',
  3: 'Explorador',
  4: 'Experto',
  5: 'Maestro'
};

String _levelName(int level) => _levelNames[level] ?? 'Leyenda';

class AchievementsScreen extends StatefulWidget {
  final Session session;
  const AchievementsScreen({super.key, required this.session});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Achievement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.session.api.achievements();
      if (mounted)
        setState(() {
          _items = all;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bal = widget.session.balance;
    final level = bal?.level ?? 1;
    final earned = bal?.earnedPoints ?? 0;
    final progress = (earned % 1000) / 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis logros'),
        bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Insignias'), Tab(text: 'Progreso')]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(SipiRadii.xl),
                      border: Border.all(color: SipiColors.border),
                      boxShadow: SipiShadows.card,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF9D7BFF),
                                  Color(0xFF4A2FD6)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius:
                                BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C5CFF)
                                    .withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.emoji_events,
                              color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 12),
                        Text('Nivel $level',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: SipiColors.text,
                                letterSpacing: -0.3)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C5CFF)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_levelName(level),
                              style: const TextStyle(
                                  color: Color(0xFF4A2FD6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: SipiColors.border,
                              color: const Color(0xFF7C5CFF)),
                        ),
                        const SizedBox(height: 8),
                        Text('${earned % 1000} / 1,000 pts',
                            style: const TextStyle(
                                color: SipiColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _badgesGrid(),
                      _progressList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _badgesGrid() {
    if (_items.isEmpty)
      return const EmptyState(
          icon: Icons.emoji_events_outlined, message: 'Aún no hay logros.');
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final a = _items[i];
        return Opacity(
          opacity: a.earned ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SipiRadii.lg),
              border: Border.all(
                color: a.earned
                    ? SipiColors.primary.withValues(alpha: 0.25)
                    : SipiColors.border,
              ),
            ),
            child: Column(children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: a.earned
                      ? LinearGradient(colors: [
                          SipiColors.primary.withValues(alpha: 0.16),
                          SipiColors.primary.withValues(alpha: 0.06),
                        ])
                      : null,
                  color: a.earned ? null : SipiColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  a.earned ? Icons.verified : Icons.lock_outline,
                  color: a.earned ? SipiColors.primary : SipiColors.muted,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(a.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SipiColors.text,
                        height: 1.25)),
              ),
              if (a.earned && a.bonusPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('+${a.bonusPoints} pts',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SipiColors.primary)),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _progressList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final a = _items[i];
        final p = (a.progress / a.threshold).clamp(0.0, 1.0);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if (a.earned)
                  const Icon(Icons.check_circle,
                      color: SipiColors.success, size: 20),
              ]),
              Text(a.description,
                  style:
                      const TextStyle(color: SipiColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: p,
                    minHeight: 6,
                    backgroundColor: SipiColors.border),
              ),
              const SizedBox(height: 4),
              Text('${a.progress} / ${a.threshold}',
                  style:
                      const TextStyle(color: SipiColors.muted, fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}
