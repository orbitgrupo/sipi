// Sipi — Canjear recompensas e historial de pagos (pantallas 9 y 10).
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../widgets/common.dart';

class RedeemScreen extends StatefulWidget {
  final Session session;
  const RedeemScreen({super.key, required this.session});
  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  int? _selectedPoints;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final bal = widget.session.balance;
    final ppu = bal?.pointsPerUsd ?? 50;
    final points = bal?.points ?? 0;
    // Montos derivados de la conversión del servidor, nunca hardcodeados.
    final options = [1.0, 5.0, 10.0, 25.0, 50.0, 100.0]
        .map((usd) => (usd: usd, pts: (usd * ppu).round()))
        .toList();
    double? selectedUsd;
    for (final o in options) {
      if (o.pts == _selectedPoints) selectedUsd = o.usd;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canjear recompensas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PaymentHistoryScreen(session: widget.session))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BalanceCard(points: points, usd: bal?.usd ?? 0),
          const SizedBox(height: 24),
          const Text('Elige un monto',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SipiColors.text)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15),
            itemCount: options.length,
            itemBuilder: (_, i) {
              final o = options[i];
              final selected = _selectedPoints == o.pts;
              final affordable = points >= o.pts;
              return GestureDetector(
                onTap: affordable
                    ? () => setState(() => _selectedPoints = o.pts)
                    : null,
                child: Opacity(
                  opacity: affordable ? 1 : 0.45,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF2F63F0),
                                SipiColors.primaryDark
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: selected ? null : Colors.white,
                      borderRadius:
                          BorderRadius.circular(SipiRadii.lg),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : SipiColors.border,
                        width: 1.2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: SipiColors.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : SipiShadows.soft,
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('\$${o.usd.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                  color: selected
                                      ? Colors.white
                                      : SipiColors.text)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : SipiColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${o.pts} pts',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : SipiColors.primary)),
                          ),
                        ]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SipiButton(
            label: selectedUsd == null
                ? 'Elige un monto'
                : 'Canjear por \$${selectedUsd.toStringAsFixed(2)}',
            loading: _loading,
            onPressed: selectedUsd == null ? null : _redeem,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: SipiColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Información\nEl tipo de cambio se calcula con la configuración actual. Tu recompensa se enviará al método de pago registrado. El tiempo de procesamiento es de 1 a 3 días hábiles.',
                      style: TextStyle(
                          color: SipiColors.muted, fontSize: 12, height: 1.5),
                    ),
                  ),
                ]),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem() async {
    final pts = _selectedPoints;
    if (pts == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar canje'),
        content: Text('¿Canjear $pts puntos? Esta acción debitará tu saldo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Canjear')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await widget.session.api.redeem(pts);
      await widget.session.refreshBalance();
      setState(() => _selectedPoints = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('¡Canje solicitado! Lo verás en tu historial.')),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class PaymentHistoryScreen extends StatefulWidget {
  final Session session;
  const PaymentHistoryScreen({super.key, required this.session});
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String _tab = 'todos';
  List<Redemption> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.session.api.redemptions();
      if (mounted) {
        setState(() {
          _items = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((r) {
      if (_tab == 'todos') return true;
      if (_tab == 'completados') return r.status == 'completed';
      return r.status == 'pending';
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'completados', label: Text('Completados')),
                ButtonSegment(value: 'pendientes', label: Text('Pendientes')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Aún no tienes canjes.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final done = r.status == 'completed';
                          final rejected = r.status == 'rejected';
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color:
                                      SipiColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.attach_money,
                                    color: SipiColors.primary),
                              ),
                              title: Text('\$${r.amountUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text('${r.points} puntos',
                                  style: const TextStyle(
                                      color: SipiColors.muted, fontSize: 12)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (done
                                          ? SipiColors.success
                                          : rejected
                                              ? SipiColors.danger
                                              : SipiColors.warning)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  done
                                      ? 'Completado'
                                      : rejected
                                          ? 'Rechazado'
                                          : 'Pendiente',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: done
                                        ? SipiColors.success
                                        : rejected
                                            ? SipiColors.danger
                                            : SipiColors.warning,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
