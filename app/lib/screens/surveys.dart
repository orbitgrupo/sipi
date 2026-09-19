// Sipi — Encuestas: lista y pantalla para responder (única, múltiple,
// sí/no, escala y texto). Pantalla 8 del mockup.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'tasks.dart' show TaskSuccessScreen;

class SurveysScreen extends StatefulWidget {
  final Session session;
  const SurveysScreen({super.key, required this.session});
  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  List<Task> _surveys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.session.api.tasks();
      if (mounted) {
        setState(() {
          _surveys = all
              .where(
                  (t) => t.category == 'encuestas' || t.category == 'opinion')
              .toList();
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
      appBar: AppBar(title: const Text('Encuestas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? const EmptyState(
                  icon: Icons.poll_outlined,
                  message: 'No hay encuestas disponibles.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _surveys.length,
                    itemBuilder: (_, i) => TaskCard(
                      task: _surveys[i],
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SurveyAnswerScreen(
                                    session: widget.session,
                                    taskId: _surveys[i].id,
                                    title: _surveys[i].title)));
                        _load();
                      },
                    ),
                  ),
                ),
    );
  }
}

class SurveyAnswerScreen extends StatefulWidget {
  final Session session;
  final int taskId;
  final String title;
  const SurveyAnswerScreen(
      {super.key,
      required this.session,
      required this.taskId,
      required this.title});
  @override
  State<SurveyAnswerScreen> createState() => _SurveyAnswerScreenState();
}

class _SurveyAnswerScreenState extends State<SurveyAnswerScreen> {
  Survey? _survey;
  bool _loading = true;
  bool _sending = false;
  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.session.api.survey(widget.taskId);
      if (mounted) {
        setState(() {
          _survey = s;
          _loading = false;
          for (final q in s.questions) {
            if (q.type == 'multiple') _answers[q.id] = <String>[];
            if (q.type == 'scale')
              _answers[q.id] = ((q.min + q.max) / 2).round();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final r = await widget.session.api.answerSurvey(widget.taskId, _answers);
      await widget.session.refreshBalance();
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => TaskSuccessScreen(
                  points: (r['points'] ?? 0) as int,
                  autoApproved: r['auto_approved'] == true)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _survey;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const EmptyState(
                  icon: Icons.error_outline,
                  message: 'No se pudo cargar la encuesta.')
              : s.answered
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      message: 'Ya respondiste esta encuesta. ¡Gracias!')
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: s.questions.length,
                            itemBuilder: (_, i) => _QuestionCard(
                              question: s.questions[i],
                              index: i + 1,
                              value: _answers[s.questions[i].id],
                              onChanged: (v) => setState(
                                  () => _answers[s.questions[i].id] = v),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SipiButton(
                              label: 'Enviar respuestas',
                              loading: _sending,
                              onPressed: _submit),
                        ),
                      ],
                    ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final SurveyQuestion question;
  final int index;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  const _QuestionCard(
      {required this.question,
      required this.index,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$index. ${question.text}${question.required ? ' *' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SipiColors.text)),
            const SizedBox(height: 12),
            _input(),
          ],
        ),
      ),
    );
  }

  Widget _input() {
    switch (question.type) {
      case 'single':
        return RadioGroup<String>(
          groupValue: value as String?,
          onChanged: (v) => onChanged(v),
          child: Column(
            children: question.options.map((o) {
              return RadioListTile<String>(
                value: o,
                title: Text(o),
                activeColor: SipiColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
        );
      case 'multiple':
        {
          final selected = (value as List?)?.cast<String>() ?? <String>[];
          return Column(
            children: question.options.map((o) {
              final isOn = selected.contains(o);
              return CheckboxListTile(
                value: isOn,
                title: Text(o),
                activeColor: SipiColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (v) {
                  final next = List<String>.from(selected);
                  if (v == true) {
                    next.add(o);
                  } else {
                    next.remove(o);
                  }
                  onChanged(next);
                },
              );
            }).toList(),
          );
        }
      case 'yesno':
        return SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Sí')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: value is bool ? {value as bool} : const <bool>{},
          onSelectionChanged: (s) => onChanged(s.first),
        );
      case 'scale':
        {
          final v = (value as int?) ?? question.min;
          return Column(children: [
            Slider(
              value: v.toDouble(),
              min: question.min.toDouble(),
              max: question.max.toDouble(),
              divisions: question.max - question.min,
              label: '$v',
              activeColor: SipiColors.primary,
              onChanged: (x) => onChanged(x.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${question.min}'),
                Text('$v', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${question.max}')
              ],
            ),
          ]);
        }
      case 'text':
        return TextField(
          maxLines: 3,
          decoration:
              const InputDecoration(hintText: 'Escribe tu respuesta...'),
          onChanged: onChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
