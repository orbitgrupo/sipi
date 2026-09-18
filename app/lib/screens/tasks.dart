// Sipi — Tareas: lista con filtros/búsqueda, detalle y pantalla de éxito.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'surveys.dart';

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
  const TasksScreen({super.key, required this.session});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _tab = 'todas';
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
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
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
      if (mounted) {
        setState(() {
          _task = d.task;
          _mine = d.mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  bool get _hasPending => _mine.any((c) => c.status == 'pending');
  bool get _hasApproved => _mine.any((c) => c.status == 'approved');

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.session.api.submitTask(widget.taskId);
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
      appBar: AppBar(actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border))
      ]),
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
                      Container(
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
                          const Text('Ir a la cuenta',
                              style: TextStyle(
                                  color: SipiColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
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
                      const _StatusBanner(
                          icon: Icons.hourglass_empty,
                          text: 'Enviada. Tu actividad está siendo verificada.',
                          color: SipiColors.warning)
                    else if (!_started)
                      SipiButton(
                          label: 'Realizar tarea',
                          onPressed: () => setState(() => _started = true))
                    else
                      SipiButton(
                          label: 'Enviar para verificar',
                          loading: _sending,
                          onPressed: _submit),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Pantalla 7 del mockup: confirmación de tarea completada.
class TaskSuccessScreen extends StatelessWidget {
  final int points;
  final bool autoApproved;
  const TaskSuccessScreen(
      {super.key, this.points = 0, this.autoApproved = true});

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
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                    color: SipiColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check,
                    color: SipiColors.success, size: 60),
              ),
              const SizedBox(height: 24),
              const Text('¡Tarea completada!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: SipiColors.text)),
              if (autoApproved && points > 0)
                Text('+$points puntos',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SipiColors.primary)),
              const SizedBox(height: 12),
              Text(
                autoApproved
                    ? 'Tu actividad está siendo verificada.\nRecibirás tus puntos en unos minutos.'
                    : 'Tu actividad está siendo verificada.\nTe avisaremos cuando se acrediten tus puntos.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SipiColors.muted, height: 1.5),
              ),
              const Spacer(),
              SipiButton(
                  label: 'Ver más tareas',
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
