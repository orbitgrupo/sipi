// Sipi — shell principal con navegación inferior + pantalla de Inicio.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'tasks.dart';
import 'redeem.dart';
import 'achievements.dart';
import 'profile.dart';

class MainShell extends StatefulWidget {
  final Session session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
          session: widget.session,
          onSeeAllTasks: () => setState(() => _index = 1)),
      TasksScreen(session: widget.session),
      AchievementsScreen(session: widget.session),
      RedeemScreen(session: widget.session),
      ProfileScreen(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.task_outlined),
              selectedIcon: Icon(Icons.task),
              label: 'Tareas'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Logros'),
          NavigationDestination(
              icon: Icon(Icons.card_giftcard_outlined),
              selectedIcon: Icon(Icons.card_giftcard),
              label: 'Canjear'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Session session;
  final VoidCallback onSeeAllTasks;
  const HomeScreen(
      {super.key, required this.session, required this.onSeeAllTasks});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _recommended = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await widget.session.api.tasks();
      if (mounted)
        setState(() {
          _recommended = tasks.take(4).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await widget.session.refreshBalance();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final bal = s.balance;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hola,',
                            style: TextStyle(
                                color: SipiColors.muted, fontSize: 14)),
                        Text(s.firstName.isEmpty ? '¡Bienvenido!' : s.firstName,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: SipiColors.text)),
                      ]),
                  Row(children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(SipiRadii.md),
                        border:
                            Border.all(color: SipiColors.border),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    NotificationsScreen(session: s))),
                        icon: const Icon(Icons.notifications_outlined,
                            size: 20),
                        color: SipiColors.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2F63F0),
                            SipiColors.primaryDark
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(SipiRadii.md),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                          s.firstName.isEmpty
                              ? 'S'
                              : s.firstName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 18),
              if (bal != null) BalanceCard(points: bal.points, usd: bal.usd),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Categorías'),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _CategoryTile(
                        icon: Icons.task_alt_outlined,
                        label: 'Tareas',
                        color: SipiColors.primary),
                    _CategoryTile(
                        icon: Icons.poll_outlined,
                        label: 'Encuestas',
                        color: Color(0xFFF5A623)),
                    _CategoryTile(
                        icon: Icons.share_outlined,
                        label: 'Redes',
                        color: Color(0xFFE1306C)),
                    _CategoryTile(
                        icon: Icons.local_offer_outlined,
                        label: 'Ofertas',
                        color: Color(0xFF22B573)),
                    _CategoryTile(
                        icon: Icons.grid_view_outlined,
                        label: 'Más',
                        color: SipiColors.muted),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionHeader(
                  title: 'Tareas recomendadas',
                  action: 'Ver todas',
                  onAction: widget.onSeeAllTasks),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
              else if (_recommended.isEmpty)
                const EmptyState(
                    icon: Icons.task_outlined,
                    message: 'No hay tareas disponibles por ahora.')
              else
                ..._recommended.map((t) => TaskCard(
                      task: t,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailScreen(session: s, taskId: t.id))),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CategoryTile(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.07)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(SipiRadii.lg),
              border: Border.all(
                  color: color.withValues(alpha: 0.18), width: 1)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SipiColors.text)),
      ]),
    );
  }
}
