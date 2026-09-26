// Sipi — Bienvenida, Registro e Inicio de sesión (pantallas 1-3 del mockup).
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'profile.dart';

class WelcomeScreen extends StatelessWidget {
  final Session session;
  const WelcomeScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Logo sin fotografía de personas: insignia con gradiente + marca.
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [SipiColors.primaryLight, SipiColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: SipiColors.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 18),
                      const Text('Sipi',
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: SipiColors.text,
                              letterSpacing: -1)),
                      const SizedBox(height: 8),
                      const Text('Tareas de hoy,\nrecompensas para mañana',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, color: SipiColors.muted, height: 1.45)),
                      const Spacer(),
                      // Ilustración abstracta (sin personas): ondas.
                      SizedBox(
                        height: 150,
                        child: CustomPaint(
                            painter: _WavesPainter(),
                            size: const Size(double.infinity, 150)),
                      ),
                      const Spacer(),
                      SipiButton(
                        label: 'Crear cuenta',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RegisterScreen(session: session))),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: SipiColors.primary),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => LoginScreen(session: session))),
                        child: const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paints = [
      Paint()..color = SipiColors.primary.withValues(alpha: 0.08),
      Paint()..color = SipiColors.primary.withValues(alpha: 0.12),
      Paint()..color = SipiColors.primary.withValues(alpha: 0.18),
    ];
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final baseY = size.height * (0.35 + i * 0.2);
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        path.lineTo(
            x,
            baseY +
                18 *
                    (i + 1) *
                    (0.5 + 0.5 * (x / size.width)) *
                    (x % 64 < 32 ? 1 : -1) *
                    0.4);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paints[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RegisterScreen extends StatefulWidget {
  final Session session;
  const RegisterScreen({super.key, required this.session});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.session
          .register(_name.text.trim(), _email.text.trim(), _pass.text);
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ThanksScreen()));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text('Crea tu cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: SipiColors.text)),
                  SizedBox(height: 6),
                  Text('Únete a Sipi y comienza\na ganar recompensas',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: SipiColors.muted, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
                controller: _name,
                decoration: const InputDecoration(
                    hintText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline))),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SipiButton(
                label: 'Crear cuenta', loading: _loading, onPressed: _submit),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LoginScreen(session: widget.session))),
                child: const Text.rich(
                  TextSpan(
                      text: '¿Ya tienes una cuenta? ',
                      style: TextStyle(color: SipiColors.muted),
                      children: [
                        TextSpan(
                            text: 'Inicia sesión',
                            style: TextStyle(
                                color: SipiColors.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Session session;
  const LoginScreen({super.key, required this.session});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.session.login(_email.text.trim(), _pass.text);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text('Bienvenido de nuevo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: SipiColors.text)),
                  SizedBox(height: 6),
                  Text('Inicia sesión en tu cuenta',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: SipiColors.muted, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline))),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SupportScreen(session: widget.session))),
                child: const Text('Olvidé mi contraseña',
                    style: TextStyle(
                        color: SipiColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),
            SipiButton(
                label: 'Iniciar sesión', loading: _loading, onPressed: _submit),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RegisterScreen(session: widget.session))),
                child: const Text.rich(
                  TextSpan(
                      text: '¿No tienes una cuenta? ',
                      style: TextStyle(color: SipiColors.muted),
                      children: [
                        TextSpan(
                            text: 'Regístrate',
                            style: TextStyle(
                                color: SipiColors.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
