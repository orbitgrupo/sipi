// Sipi — Perfil, Notificaciones, Soporte, Configuración, Más y pantalla final
// (pantallas 12-17 del mockup).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import 'redeem.dart' show PaymentHistoryScreen;
import 'achievements.dart';
import 'legal.dart';
import 'welcome_auth.dart' show RegisterScreen;

// ---------------- Perfil ----------------
class ProfileScreen extends StatelessWidget {
  final Session session;
  const ProfileScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final u = session.user;
    final bal = session.balance;
    if (session.isGuest) return _guestProfile(context);
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
              if (u != null && !u.approved) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: SipiColors.warningSoft,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.hourglass_empty,
                          size: 14, color: SipiColors.warningDark),
                      SizedBox(width: 6),
                      Text('Cuenta pendiente de aprobación',
                          style: TextStyle(
                              color: SipiColors.warningDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          _MenuItem(
              icon: Icons.edit_outlined,
              label: 'Editar perfil',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditProfileScreen(session: session)))),
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

  /// Perfil del invitado: tarjeta para crear cuenta + opciones informativas.
  Widget _guestProfile(BuildContext context) {
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
                child: const Icon(Icons.person_outline,
                    size: 40, color: SipiColors.primary),
              ),
              const SizedBox(height: 10),
              const Text('Invitado',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              const Text('Explora Sipi sin compromiso',
                  style: TextStyle(color: SipiColors.muted)),
              const SizedBox(height: 16),
              SipiButton(
                  label: 'Crear cuenta gratis',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              RegisterScreen(session: session)))),
            ]),
          ),
          const SizedBox(height: 24),
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
              label: 'Salir del modo invitado',
              danger: true,
              onTap: () => session.exitGuestMode()),
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

// ---------------- Editar perfil ----------------
class EditProfileScreen extends StatefulWidget {
  final Session session;
  const EditProfileScreen({super.key, required this.session});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _loading = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.session.user?.name ?? '');
    _email = TextEditingController(text: widget.session.user?.email ?? '');
    _name.addListener(_onChanged);
    _email.addListener(_onChanged);
  }

  void _onChanged() {
    final dirty = _name.text.trim() != (widget.session.user?.name ?? '') ||
        _email.text.trim() != (widget.session.user?.email ?? '');
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      showError(context, ApiException(400, 'MISSING_FIELDS'));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.updateProfile(name: name, email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.session.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SipiColors.primaryLight, SipiColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: SipiColors.primary.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                  (u?.name ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nombre',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: SipiColors.text)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Tu nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Correo electrónico',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: SipiColors.text)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'tu@correo.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SipiRadii.md)),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SipiColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: SipiColors.primary, size: 20),
                ),
                title: const Text('Cambiar contraseña',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Actualiza tu contraseña',
                    style: TextStyle(color: SipiColors.muted, fontSize: 12)),
                trailing:
                    const Icon(Icons.chevron_right, color: SipiColors.muted),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ChangePasswordScreen(session: widget.session))),
              ),
            ),
            const SizedBox(height: 28),
            SipiButton(
              label: 'Guardar cambios',
              loading: _loading,
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Cambiar contraseña ----------------
class ChangePasswordScreen extends StatefulWidget {
  final Session session;
  const ChangePasswordScreen({super.key, required this.session});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _nueva = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _nueva.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nueva.text != _confirm.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Las contraseñas nuevas no coinciden.')));
      }
      return;
    }
    if (_nueva.text.length < 6) {
      showError(context, ApiException(400, 'WEAK_PASSWORD'));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.api.changePassword(
        currentPassword: _current.text,
        newPassword: _nueva.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SipiColors.primarySoft,
                borderRadius: BorderRadius.circular(SipiRadii.lg),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: SipiColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Usa al menos 6 caracteres. No compartas tu contraseña con nadie.',
                    style: TextStyle(
                        color: SipiColors.text, fontSize: 13, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Contraseña actual',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SipiColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _current,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Nueva contraseña',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SipiColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _nueva,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                hintText: 'Mínimo 6 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Confirmar nueva contraseña',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SipiColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: 'Repite la nueva contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SipiButton(
              label: 'Actualizar contraseña',
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
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
                        subtitle: Text(
                            m.note.isEmpty
                                ? _shortDate(m.createdAt)
                                : _typeLabel(m.type),
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

  String _shortDate(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;
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
class SupportScreen extends StatefulWidget {
  final Session session;
  const SupportScreen({super.key, required this.session});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.session.canInteract) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final t = await widget.session.api.supportThreads();
      if (mounted) setState(() {
        _threads = t;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _needAccount() async {
    if (await ensureAccount(context, widget.session) && mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => RegisterScreen(session: widget.session)));
    }
  }

  void _faq(String topic, String answer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(topic),
        content: Text(answer, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String k) =>
      {'pregunta': 'Pregunta', 'queja': 'Queja', 'sugerencia': 'Sugerencia'}[k] ?? k;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
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
            const SizedBox(height: 20),
            SipiButton(
                label: 'Enviar mensaje',
                onPressed: () async {
                  if (!widget.session.canInteract) {
                    await _needAccount();
                    return;
                  }
                  final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              NewSupportThreadScreen(session: widget.session)));
                  if (created == true) _load();
                }),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (widget.session.canInteract && _threads.isNotEmpty) ...[
              const Text('Mis conversaciones',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: SipiColors.text)),
              const SizedBox(height: 10),
              ..._threads.map((t) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (t['unread_user'] == true)
                            ? SipiColors.primary
                            : SipiColors.muted.withValues(alpha: 0.25),
                        child: Icon(
                            t['kind'] == 'queja'
                                ? Icons.report_outlined
                                : Icons.chat_bubble_outline,
                            color: (t['unread_user'] == true)
                                ? Colors.white
                                : SipiColors.muted),
                      ),
                      title: Text(
                          (t['subject'] as String?)?.isNotEmpty == true
                              ? t['subject'] as String
                              : 'Conversación',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: (t['unread_user'] == true)
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      subtitle: Text(
                          '${_kindLabel(t['kind'] as String? ?? '')} · ${(t['last_message'] as String?) ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: (t['status'] as String?) == 'closed'
                          ? const Text('Cerrada',
                              style: TextStyle(
                                  color: SipiColors.muted, fontSize: 12))
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SupportChatScreen(
                                    session: widget.session,
                                    threadId: (t['id'] as num).toInt(),
                                    subject: (t['subject'] as String?) ?? '')));
                        _load();
                      },
                    ),
                  )),
              const SizedBox(height: 14),
            ],
            const Text('Temas comunes',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: SipiColors.text)),
            const SizedBox(height: 10),
            _MenuItem(
                icon: Icons.task_outlined,
                label: 'Problemas con tareas',
                onTap: () => _faq('Problemas con tareas',
                    'Si una tarea no se acredita, verifica que hayas completado todos los pasos y enviado la verificación. Las tareas manuales se revisan en un máximo de 48 horas.')),
            _MenuItem(
                icon: Icons.payments_outlined,
                label: 'Pagos y recompensas',
                onTap: () => _faq('Pagos y recompensas',
                    'Puedes canjear tus puntos desde la pestaña Canjear cuando alcances el mínimo. Los pagos se procesan en 1 a 3 días hábiles.')),
            _MenuItem(
                icon: Icons.person_outline,
                label: 'Mi cuenta',
                onTap: () => _faq('Mi cuenta',
                    'Puedes actualizar tu nombre, correo y contraseña desde Perfil > Editar perfil. Si no puedes entrar a tu cuenta, escríbenos con el botón de arriba.')),
            _MenuItem(
                icon: Icons.report_outlined,
                label: 'Reportar un problema',
                onTap: () => _faq('Reportar un problema',
                    'Cuéntanos qué pasó con el botón "Enviar mensaje" e incluye detalles. Te responderemos lo más pronto posible.')),
          ],
        ),
      ),
    );
  }
}

// ---------------- Nueva consulta ----------------
class NewSupportThreadScreen extends StatefulWidget {
  final Session session;
  const NewSupportThreadScreen({super.key, required this.session});

  @override
  State<NewSupportThreadScreen> createState() => _NewSupportThreadScreenState();
}

class _NewSupportThreadScreenState extends State<NewSupportThreadScreen> {
  String _kind = 'pregunta';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _message.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe tu mensaje primero.')));
      return;
    }
    setState(() => _sending = true);
    try {
      final t = await widget.session.api.createSupportThread(
          kind: _kind,
          subject: _subject.text.trim(),
          message: msg);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => SupportChatScreen(
                  session: widget.session,
                  threadId: (t['id'] as num).toInt(),
                  subject: (t['subject'] as String?) ?? '')));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const kinds = ['pregunta', 'queja', 'sugerencia'];
    const labels = {'pregunta': 'Pregunta', 'queja': 'Queja', 'sugerencia': 'Sugerencia'};
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva consulta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Tipo de mensaje',
              style: TextStyle(fontWeight: FontWeight.w800, color: SipiColors.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: kinds
                .map((k) => ChoiceChip(
                      label: Text(labels[k]!),
                      selected: _kind == k,
                      selectedColor: SipiColors.primary.withValues(alpha: 0.15),
                      onSelected: (_) => setState(() => _kind = k),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Asunto (opcional)',
              style: TextStyle(fontWeight: FontWeight.w800, color: SipiColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(hintText: 'Ej. No recibí mis puntos'),
          ),
          const SizedBox(height: 16),
          const Text('Mensaje',
              style: TextStyle(fontWeight: FontWeight.w800, color: SipiColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            maxLines: 5,
            decoration: const InputDecoration(
                hintText: 'Cuéntanos qué pasó con el mayor detalle posible…'),
          ),
          const SizedBox(height: 20),
          SipiButton(label: 'Enviar', loading: _sending, onPressed: _send),
        ],
      ),
    );
  }
}

// ---------------- Chat de soporte ----------------
class SupportChatScreen extends StatefulWidget {
  final Session session;
  final int threadId;
  final String subject;
  const SupportChatScreen(
      {super.key,
      required this.session,
      required this.threadId,
      required this.subject});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  String _status = 'open';
  bool _loading = true;
  bool _sending = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await widget.session.api.supportThread(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages = ((d['messages'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _status = (d['thread'] as Map?)?['status'] as String? ?? 'open';
        _loading = false;
      });
      _toBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final msg = _input.text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.session.api.sendSupportMessage(widget.threadId, msg);
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.subject.isNotEmpty ? widget.subject : 'Soporte')),
      body: Column(
        children: [
          if (_status == 'closed')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: SipiColors.muted.withValues(alpha: 0.15),
              child: const Text('Esta conversación está cerrada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SipiColors.muted, fontSize: 13)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _messages.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 60),
                            Center(
                                child: Text('Sin mensajes.',
                                    style: TextStyle(color: SipiColors.muted)))
                          ])
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              final mine = m['sender'] == 'user';
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? SipiColors.primary
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(mine ? 16 : 4),
                                      bottomRight:
                                          Radius.circular(mine ? 4 : 16),
                                    ),
                                  ),
                                  child: Text(
                                    (m['body'] as String?) ?? '',
                                    style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : SipiColors.text,
                                        height: 1.4),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          if (_status == 'open')
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        decoration: const InputDecoration(
                            hintText: 'Escribe tu mensaje…'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- Configuración ----------------
class SettingsScreen extends StatelessWidget {
  final Session session;
  const SettingsScreen({super.key, required this.session});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label estará disponible próximamente.')),
    );
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Sipi',
      applicationVersion: '1.0.0',
      applicationLegalese:
          'Gana puntos completando tareas y canjéalos por recompensas.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsGroup(title: 'Cuenta', items: [
            _SettingsItem(
                icon: Icons.notifications_outlined,
                label: 'Notificaciones',
                onTap: () => _soon(context, 'Las notificaciones')),
            _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacidad',
                onTap: () => _soon(context, 'La configuración de privacidad')),
            _SettingsItem(
                icon: Icons.security_outlined,
                label: 'Seguridad',
                onTap: () => _soon(context, 'La configuración de seguridad')),
          ]),
          _SettingsGroup(title: 'Preferencias', items: [
            _SettingsItem(
                icon: Icons.language_outlined,
                label: 'Idioma',
                onTap: () => _soon(context, 'El cambio de idioma')),
            _SettingsItem(
                icon: Icons.palette_outlined,
                label: 'Tema',
                value: 'Claro',
                onTap: () => _soon(context, 'El cambio de tema')),
            _SettingsItem(
                icon: Icons.storage_outlined,
                label: 'Procesamiento de datos',
                onTap: () => _soon(context, 'El procesamiento de datos')),
          ]),
          _SettingsGroup(title: 'Información', items: [
            _SettingsItem(
                icon: Icons.description_outlined,
                label: 'Términos y condiciones',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsScreen()))),
            _SettingsItem(
                icon: Icons.policy_outlined,
                label: 'Política de privacidad',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyScreen()))),
            _SettingsItem(
                icon: Icons.info_outline,
                label: 'Acerca de Sipi',
                onTap: () => _about(context)),
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
  final VoidCallback? onTap;
  const _SettingsItem(
      {required this.icon, required this.label, this.value, this.onTap});
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
        onTap: onTap,
      ),
    );
  }
}

// ---------------- Más / Menú ----------------
class MoreScreen extends StatelessWidget {
  final Session session;
  const MoreScreen({super.key, required this.session});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label estará disponible próximamente.')),
    );
  }

  Future<void> _invite(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(
        text: '¡Únete a Sipi! Completa tareas y gana recompensas.'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('¡Texto copiado! Compártelo con tus amigos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MenuItem(
              icon: Icons.group_add_outlined,
              label: 'Invitar amigos\nComparte Sipi con tus amigos',
              onTap: () => _invite(context)),
          _MenuItem(
              icon: Icons.help_outline,
              label: 'Centro de ayuda\nPreguntas frecuentes',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SupportScreen(session: session)))),
          _MenuItem(
              icon: Icons.article_outlined,
              label: 'Blog\nNovedades y consejos',
              onTap: () => _soon(context, 'El blog')),
          _MenuItem(
              icon: Icons.star_outline,
              label: 'Calificar la app\nNos ayuda mucho',
              onTap: () => _soon(context, 'La calificación de la app')),
          _MenuItem(
              icon: Icons.logout_outlined,
              label: session.isGuest
                  ? 'Salir del modo invitado'
                  : 'Cerrar sesión',
              danger: true,
              onTap: () {
                if (session.isGuest) {
                  session.exitGuestMode();
                } else {
                  session.logout();
                  Navigator.popUntil(context, (r) => r.isFirst);
                }
              }),
        ],
      ),
    );
  }
}

