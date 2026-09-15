// Sipi — Perfil, Notificaciones, Soporte, Configuración, Más y pantalla final
// (pantallas 12-17 del mockup).
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'redeem.dart' show PaymentHistoryScreen;
import 'achievements.dart';

// ---------------- Perfil ----------------
class ProfileScreen extends StatelessWidget {
  final Session session;
  const ProfileScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final u = session.user;
    final bal = session.balance;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: SipiColors.primary.withValues(alpha: 0.12),
                child: Text((u?.name ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: SipiColors.primary)),
              ),
              const SizedBox(height: 10),
              Text(u?.name ?? '',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              Text(u?.email ?? '',
                  style: const TextStyle(color: SipiColors.muted)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: SipiColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    '${bal?.points ?? 0} pts · Nivel ${bal?.level ?? 1}',
                    style: const TextStyle(
                        color: SipiColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _MenuItem(
              icon: Icons.edit_outlined, label: 'Editar perfil', onTap: () {}),
          _MenuItem(
              icon: Icons.credit_card_outlined,
              label: 'Métodos de pago',
              onTap: () {}),
          _MenuItem(
              icon: Icons.emoji_events_outlined,
              label: 'Mis logros',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AchievementsScreen(session: session)))),
          _MenuItem(
              icon: Icons.history_outlined,
              label: 'Historial de puntos',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PointsHistoryScreen(session: session)))),
          _MenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Historial de pagos',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PaymentHistoryScreen(session: session)))),
          _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notificaciones',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NotificationsScreen(session: session)))),
          _MenuItem(
              icon: Icons.support_agent_outlined,
              label: 'Soporte',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SupportScreen(session: session)))),
          _MenuItem(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(session: session)))),
          _MenuItem(
              icon: Icons.logout_outlined,
              label: 'Cerrar sesión',
              danger: true,
              onTap: () {
                session.logout();
                Navigator.popUntil(context, (r) => r.isFirst);
              }),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading:
            Icon(icon, color: danger ? SipiColors.danger : SipiColors.muted),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: danger ? SipiColors.danger : SipiColors.text)),
        trailing: const Icon(Icons.chevron_right, color: SipiColors.muted),
        onTap: onTap,
      ),
    );
  }
}

// ---------------- Historial de puntos (ledger) ----------------
class PointsHistoryScreen extends StatefulWidget {
  final Session session;
  const PointsHistoryScreen({super.key, required this.session});
  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  List<LedgerMovement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.session.api.ledger();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de puntos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.history_outlined,
                  message: 'Aún no tienes movimientos.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    final positive = m.points > 0;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Icon(
                          positive
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color:
                              positive ? SipiColors.success : SipiColors.danger,
                        ),
                        title: Text(
                            m.note.isEmpty ? _typeLabel(m.type) : m.note,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(_typeLabel(m.type),
                            style: const TextStyle(
                                color: SipiColors.muted, fontSize: 12)),
                        trailing: Text('${positive ? '+' : ''}${m.points}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: positive
                                    ? SipiColors.success
                                    : SipiColors.danger)),
                      ),
                    );
                  },
                ),
    );
  }

  String _typeLabel(String t) =>
      {
        'EARN': 'Tarea completada',
        'BONUS': 'Bonus por logro',
        'REDEEM': 'Canje',
        'REVERSAL': 'Devolución',
        'ADJUSTMENT': 'Ajuste',
      }[t] ??
      t;
}

// ---------------- Notificaciones ----------------
class NotificationsScreen extends StatefulWidget {
  final Session session;
  const NotificationsScreen({super.key, required this.session});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<SipiNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.session.api.notifications();
      if (mounted)
        setState(() {
          _items = all;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'payment':
        return Icons.payments_outlined;
      case 'achievement':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_outlined,
                  message: 'No tienes notificaciones.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: n.read
                          ? Colors.white
                          : SipiColors.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: Icon(_icon(n.type), color: SipiColors.primary),
                        title: Text(n.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(n.body,
                            style: const TextStyle(
                                color: SipiColors.muted, fontSize: 13)),
                        onTap: () {
                          widget.session.api.markNotificationRead(n.id);
                          setState(() => _items[i] = SipiNotification(
                              id: n.id,
                              type: n.type,
                              title: n.title,
                              body: n.body,
                              read: true,
                              createdAt: n.createdAt));
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// ---------------- Soporte ----------------
class SupportScreen extends StatelessWidget {
  final Session session;
  const SupportScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Column(children: [
              Icon(Icons.support_agent, size: 64, color: SipiColors.primary),
              SizedBox(height: 12),
              Text('¿En qué podemos ayudarte?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              Text('Nuestro equipo te responderá lo más\npronto posible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SipiColors.muted)),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Temas comunes',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: SipiColors.text)),
          const SizedBox(height: 10),
          _MenuItem(
              icon: Icons.task_outlined,
              label: 'Problemas con tareas',
              onTap: () {}),
          _MenuItem(
              icon: Icons.payments_outlined,
              label: 'Pagos y recompensas',
              onTap: () {}),
          _MenuItem(
              icon: Icons.person_outline, label: 'Mi cuenta', onTap: () {}),
          _MenuItem(
              icon: Icons.report_outlined,
              label: 'Reportar un problema',
              onTap: () {}),
          const SizedBox(height: 16),
          SipiButton(
              label: 'Enviar mensaje',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Mensaje enviado. Te contactaremos pronto.')));
              }),
        ],
      ),
    );
  }
}

// ---------------- Configuración ----------------
class SettingsScreen extends StatelessWidget {
  final Session session;
  const SettingsScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SettingsGroup(title: 'Cuenta', items: [
            _SettingsItem(
                icon: Icons.notifications_outlined, label: 'Notificaciones'),
            _SettingsItem(
                icon: Icons.privacy_tip_outlined, label: 'Privacidad'),
            _SettingsItem(icon: Icons.security_outlined, label: 'Seguridad'),
          ]),
          _SettingsGroup(title: 'Preferencias', items: [
            _SettingsItem(icon: Icons.language_outlined, label: 'Idioma'),
            _SettingsItem(
                icon: Icons.palette_outlined, label: 'Tema', value: 'Claro'),
            _SettingsItem(
                icon: Icons.storage_outlined, label: 'Procesamiento de datos'),
          ]),
          _SettingsGroup(title: 'Información', items: [
            _SettingsItem(
                icon: Icons.description_outlined,
                label: 'Términos y condiciones'),
            _SettingsItem(
                icon: Icons.policy_outlined, label: 'Política de privacidad'),
            _SettingsItem(icon: Icons.info_outline, label: 'Acerca de Sipi'),
          ]),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _SettingsGroup({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: SipiColors.text)),
      ),
      ...items,
      const SizedBox(height: 8),
    ]);
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _SettingsItem({required this.icon, required this.label, this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: SipiColors.muted),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            Text(value!,
                style: const TextStyle(color: SipiColors.muted, fontSize: 13)),
          const Icon(Icons.chevron_right, color: SipiColors.muted),
        ]),
        onTap: () {},
      ),
    );
  }
}

// ---------------- Más / Menú ----------------
class MoreScreen extends StatelessWidget {
  final Session session;
  const MoreScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MenuItem(
              icon: Icons.group_add_outlined,
              label: 'Invitar amigos\nGana 50 puntos por cada amigo',
              onTap: () {}),
          _MenuItem(
              icon: Icons.help_outline,
              label: 'Centro de ayuda\nPreguntas frecuentes',
              onTap: () {}),
          _MenuItem(
              icon: Icons.article_outlined,
              label: 'Blog\nNovedades y consejos',
              onTap: () {}),
          _MenuItem(
              icon: Icons.star_outline,
              label: 'Calificar la app\nNos ayuda mucho',
              onTap: () {}),
          _MenuItem(
              icon: Icons.logout_outlined,
              label: 'Cerrar sesión',
              danger: true,
              onTap: () {
                session.logout();
                Navigator.popUntil(context, (r) => r.isFirst);
              }),
        ],
      ),
    );
  }
}

// ---------------- Pantalla final ----------------
class ThanksScreen extends StatelessWidget {
  const ThanksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFF5A623)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.white, size: 72),
              ),
              const SizedBox(height: 24),
              const Text('Gracias por ser parte\nde Sipi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              const SizedBox(height: 10),
              const Text('Más tareas, más oportunidades,\nun mejor mañana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SipiColors.muted, height: 1.5)),
              const Spacer(),
              SipiButton(
                  label: 'Seguir explorando',
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
