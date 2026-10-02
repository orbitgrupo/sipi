// Sipi — Tareas: lista con filtros/búsqueda, detalle y pantalla de éxito.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../core/social_labels.dart';
import '../widgets/common.dart';
import 'surveys.dart';
import 'legal.dart';
import 'welcome_auth.dart' show RegisterScreen;

const _tabs = ['todas', 'social', 'encuestas', 'promociones'];

String _tabLabel(String t) =>
    {
      'todas': 'Todas',
      'social': 'Redes',
      'encuestas': 'Encuestas',
      'promociones': 'Ofertas'
    }[t] ??
    t;

class TasksScreen extends StatefulWidget {
  final Session session;
  final String initialTab;
  const TasksScreen({super.key, required this.session, this.initialTab = 'todas'});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late String _tab = widget.initialTab;
  String _query = '';
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tasks = await widget.session.api
          .tasks(category: _tab == 'todas' ? null : _tab, q: _query);
      if (mounted)
        setState(() {
          _tasks = tasks;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
        actions: [
          if (widget.session.canInteract)
            IconButton(
              tooltip: 'Historial',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          TaskHistoryScreen(session: widget.session))),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Buscar tareas...', prefixIcon: Icon(Icons.search)),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _tabs[i];
                final selected = t == _tab;
                return ChoiceChip(
                  label: Text(_tabLabel(t)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _tab = t);
                    _load();
                  },
                  selectedColor: SipiColors.primary,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : SipiColors.text,
                      fontWeight: FontWeight.w600),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? const EmptyState(
                        icon: Icons.task_outlined,
                        message: 'No hay tareas en esta categoría.')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tasks.length,
                          itemBuilder: (_, i) => TaskCard(
                            task: _tasks[i],
                            onTap: () => _openTask(_tasks[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTask(Task t) async {
    if (t.category == 'encuestas' || t.category == 'opinion') {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SurveyAnswerScreen(
                  session: widget.session, taskId: t.id, title: t.title)));
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  TaskDetailScreen(session: widget.session, taskId: t.id)));
    }
    _load();
    widget.session.refreshBalance();
  }
}

/// Historial de tareas completadas (aprobadas) por el usuario.
/// Las tareas completadas ya no aparecen en el inicio ni en la lista.
class TaskHistoryScreen extends StatefulWidget {
  final Session session;
  const TaskHistoryScreen({super.key, required this.session});
  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.session.api.taskHistory();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de tareas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  message: 'Aún no completas tareas.\n¡Tus logros aparecerán aquí!')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final t = _items[i];
                      final task = Task.fromJson(t);
                      final points = asInt(t['points']);
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SipiRadii.lg),
                            side:
                                const BorderSide(color: SipiColors.border)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: TaskThumb(task: task),
                          title: Text(task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(
                              'Completada el ${_fmtDate(t['completed_at'] as String?)}',
                              style: const TextStyle(
                                  fontSize: 12, color: SipiColors.muted)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: SipiColors.success
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('+$points',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: SipiColors.success,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final Session session;
  final int taskId;
  const TaskDetailScreen(
      {super.key, required this.session, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _task;
  List<TaskCompletion> _mine = [];
  bool _loading = true;
  bool _sending = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.session.api.taskDetail(widget.taskId);
      if (mounted)
        setState(() {
          _task = d.task;
          _mine = d.mine;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  bool get _hasPending => _mine.any((c) => c.status == 'pending');
  bool get _hasApproved => _mine.any((c) => c.status == 'approved');
  String? get _pendingHandle {
    for (final c in _mine) {
      if (c.status == 'pending' && (c.handle ?? '').isNotEmpty) return c.handle;
    }
    return null;
  }

  Future<void> _submit({String? handle}) async {
    final s = widget.session;
    if (!s.canInteract) {
      if (await ensureAccount(context, s) && mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RegisterScreen(session: s)));
      }
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.session.api.submitTask(widget.taskId, handle: handle);
      await widget.session.refreshBalance();
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const TaskSuccessScreen(autoApproved: false)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return Scaffold(
      appBar: AppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : t == null
              ? const EmptyState(
                  icon: Icons.error_outline,
                  message: 'No se pudo cargar la tarea.')
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: taskIconBg(t.category).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(taskIcon(t.category),
                            color: taskIconBg(t.category), size: 36),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(t.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: SipiColors.text)),
                    const SizedBox(height: 6),
                    Center(child: PointsPill(points: t.points)),
                    const SizedBox(height: 20),
                    const _DetailLabel('Descripción'),
                    Text(
                        t.description.isEmpty
                            ? 'Completa esta tarea para ganar puntos.'
                            : t.description,
                        style: const TextStyle(
                            color: SipiColors.muted, height: 1.5)),
                    if (t.targetUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _DetailLabel('Cuenta a seguir'),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: t.targetUrl));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enlace copiado al portapapeles.')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            const Icon(Icons.person_outline,
                                color: SipiColors.muted),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(t.targetUrl,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            const Text('Copiar enlace',
                                style: TextStyle(
                                    color: SipiColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _InfoRow(
                        icon: Icons.schedule_outlined,
                        label: 'Tiempo estimado',
                        value: '${t.estimatedMinutes} min'),
                    if (t.requirements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _DetailLabel('Requisitos'),
                      Text('• ${t.requirements}',
                          style: const TextStyle(
                              color: SipiColors.muted, height: 1.6)),
                    ],
                    if (t.instructions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _DetailLabel('Instrucciones'),
                      Text(t.instructions,
                          style: const TextStyle(
                              color: SipiColors.muted, height: 1.6)),
                    ],
                    const SizedBox(height: 28),
                    if (_hasApproved)
                      const _StatusBanner(
                          icon: Icons.check_circle,
                          text: 'Ya completaste esta tarea.',
                          color: SipiColors.success)
                    else if (_hasPending)
                      _StatusBanner(
                          icon: Icons.hourglass_empty,
                          text: _pendingHandle != null
                              ? 'Enviada como @$_pendingHandle. Tu actividad está siendo verificada.'
                              : 'Enviada. Tu actividad está siendo verificada.',
                          color: SipiColors.warning)
                    else if (!_started)
                      SipiButton(
                          label: 'Realizar tarea',
                          onPressed: () => setState(() => _started = true))
                    else if (t.isSocial)
                      _SocialHandleForm(
                          task: t,
                          sending: _sending,
                          onSubmit: (handle) => _submit(handle: handle))
                    else
                      SipiButton(
                          label: 'Enviar para verificar',
                          loading: _sending,
                          onPressed: () => _submit()),
                    const SizedBox(height: 12),
                    const Text(
                        'La recompensa solo se acredita después de una verificación válida.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: SipiColors.muted, fontSize: 12)),
                  ],
                ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  final String text;
  const _DetailLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: SipiColors.text)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: SipiColors.muted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: SipiColors.muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatusBanner(
      {required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    // El ámbar puro sobre fondo ámbar claro no se lee bien: usar tono oscuro.
    final fg =
        color == SipiColors.warning ? SipiColors.warningDark : color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: fg),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Pantalla 7 del mockup: confirmación de tarea completada.
/// Cuando los puntos se acreditan de inmediato (encuestas), celebra
/// con confeti y un sonido de fanfarria ("tarannn").
class TaskSuccessScreen extends StatefulWidget {
  final int points;
  final bool autoApproved;
  final String title;
  const TaskSuccessScreen(
      {super.key,
      this.points = 0,
      this.autoApproved = true,
      this.title = '¡Tarea completada!'});

  @override
  State<TaskSuccessScreen> createState() => _TaskSuccessScreenState();
}

class _TaskSuccessScreenState extends State<TaskSuccessScreen> {
  late final ConfettiController _confetti;
  final AudioPlayer _player = AudioPlayer();

  bool get _celebrate => widget.autoApproved && widget.points > 0;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (_celebrate) {
      // Confeti + "tarannn" al mostrar la pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confetti.play();
      });
      _playFanfare();
    }
  }

  Future<void> _playFanfare() async {
    try {
      await _player.play(AssetSource('sounds/fanfare.wav'));
    } catch (_) {
      // Sin audio disponible: la celebración visual sigue funcionando.
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                        color: SipiColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: SipiColors.success, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: SipiColors.text)),
                  if (_celebrate)
                    Text('+${widget.points} puntos',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SipiColors.primary)),
                  const SizedBox(height: 12),
                  Text(
                    _celebrate
                        ? '¡Felicidades! Los puntos ya están en tu saldo.'
                        : 'Tu actividad está siendo verificada.\nTe avisaremos cuando se acrediten tus puntos.',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: SipiColors.muted, height: 1.5),
                  ),
                  const Spacer(),
                  SipiButton(
                      label: 'Ver más tareas',
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_celebrate)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 60,
                  gravity: 0.35,
                  emissionFrequency: 0.05,
                  colors: const [
                    SipiColors.primary,
                    SipiColors.success,
                    Colors.amber,
                    Colors.pinkAccent,
                    Colors.lightBlue,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Formulario de tareas de redes sociales ----------------
/// Formulario para participar en una tarea de red social: el usuario indica
/// su usuario en la red para que el administrador pueda verificar la acción.
class _SocialHandleForm extends StatefulWidget {
  final Task task;
  final bool sending;
  final ValueChanged<String> onSubmit;
  const _SocialHandleForm(
      {required this.task, required this.sending, required this.onSubmit});

  @override
  State<_SocialHandleForm> createState() => _SocialHandleFormState();
}

class _SocialHandleFormState extends State<_SocialHandleForm> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() async {
    final handle = _ctrl.text.trim().replaceAll(RegExp(r'^@+'), '');
    if (handle.isEmpty) {
      setState(() => _error = 'Escribe tu usuario de ${socialNetworkName(widget.task.socialNetwork)}.');
      return;
    }
    setState(() => _error = null);
    // Abre el enlace que puso el admin (la app de la red social si está
    // instalada, o el navegador) para que el usuario complete la acción.
    final raw = widget.task.targetUrl.trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(
          raw.startsWith(RegExp(r'https?://', caseSensitive: false))
              ? raw
              : 'https://$raw');
      if (uri != null) {
        final opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No se pudo abrir el enlace. Cópialo desde el detalle de la tarea.')));
        }
      }
    }
    widget.onSubmit(handle);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final netName = socialNetworkName(t.socialNetwork);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SipiColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SipiColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SipiColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(socialNetworkIcon(t.socialNetwork),
                    color: SipiColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(socialActionText(t.socialAction, t.socialNetwork),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: SipiColors.text)),
                    const SizedBox(height: 2),
                    const Text(
                        'Indica tu usuario para que podamos verificarlo.',
                        style: TextStyle(
                            color: SipiColors.muted, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _DetailLabel('Tu usuario'),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Tu usuario de $netName',
            prefixIcon: const Icon(Icons.alternate_email),
            errorText: _error,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: SipiColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyScreen())),
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(
                        color: SipiColors.muted, fontSize: 12, height: 1.5),
                    children: [
                      TextSpan(
                          text:
                              'Tu usuario solo se usará para verificar que completaste esta tarea. '),
                      TextSpan(
                          text: 'Ver términos y privacidad.',
                          style: TextStyle(
                              color: SipiColors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SipiButton(
            label: widget.task.targetUrl.trim().isNotEmpty
                ? 'Abrir y enviar para verificar'
                : 'Enviar para verificar',
            loading: widget.sending,
            onPressed: _go),
      ],
    );
  }
}
