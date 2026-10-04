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
import 'welcome_auth.dart' show RegisterScreen;

class MainShell extends StatefulWidget {
  final Session session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  String _tasksTab = 'todas';

  void _goToTasksTab(String tab) {
    setState(() {
      _tasksTab = tab;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
          session: widget.session,
          onSeeAllTasks: () => _goToTasksTab('todas'),
          onCategoryTap: (cat) {
            if (cat == 'mas') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MoreScreen(session: widget.session)));
            } else {
              _goToTasksTab(cat);
            }
          }),
      TasksScreen(
          key: ValueKey(_tasksTab),
          session: widget.session,
          initialTab: _tasksTab),
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
  final ValueChanged<String> onCategoryTap;
  const HomeScreen(
      {super.key,
      required this.session,
      required this.onSeeAllTasks,
      required this.onCategoryTap});
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
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hola,',
                              style: TextStyle(
                                  color: SipiColors.muted, fontSize: 14)),
                          Text(
                              s.firstName.isEmpty
                                  ? '¡Bienvenido!'
                                  : s.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: SipiColors.text)),
                        ]),
                  ),
                  const SizedBox(width: 10),
                  Row(children: [
                    Container(
                      decoration: Clay.card(radius: SipiRadii.md, depth: 5),
                      child: IconButton(
                        onPressed: () async {
                          if (!s.canInteract) {
                            if (await ensureAccount(context, s) &&
                                context.mounted) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          RegisterScreen(session: s)));
                            }
                            return;
                          }
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      NotificationsScreen(session: s)));
                        },
                        icon: const Icon(Icons.notifications_outlined,
                            size: 20),
                        color: SipiColors.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: Clay.button(SipiColors.primary,
                          radius: SipiRadii.md, depth: 5),
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
              if (bal != null)
                BalanceCard(
                    points: bal.points,
                    usd: bal.usd,
                    pointsPerUsd: bal.pointsPerUsd),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Categorías'),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryTile(
                        icon: Icons.task_alt_outlined,
                        label: 'Tareas',
                        color: SipiColors.primary,
                        tab: 'todas',
                        onTap: widget.onCategoryTap),
                    _CategoryTile(
                        icon: Icons.poll_outlined,
                        label: 'Encuestas',
                        color: SipiColors.warning,
                        tab: 'encuestas',
                        onTap: widget.onCategoryTap),
                    _CategoryTile(
                        icon: Icons.share_outlined,
                        label: 'Redes',
                        color: SipiColors.pink,
                        tab: 'social',
                        onTap: widget.onCategoryTap),
                    _CategoryTile(
                        icon: Icons.local_offer_outlined,
                        label: 'Ofertas',
                        color: SipiColors.success,
                        tab: 'promociones',
                        onTap: widget.onCategoryTap),
                    _CategoryTile(
                        icon: Icons.grid_view_outlined,
                        label: 'Más',
                        color: SipiColors.muted,
                        tab: 'mas',
                        onTap: widget.onCategoryTap),
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
  final String tab;
  final ValueChanged<String> onTap;
  const _CategoryTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.tab,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(SipiRadii.lg),
        onTap: () => onTap(tab),
        child: Column(children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
                color: Color.lerp(color, Colors.white, 0.82),
                borderRadius: BorderRadius.circular(22),
                boxShadow: Clay.shadows(depth: 5)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SipiColors.text)),
        ]),
      ),
    );
  }
}
