// Sipi — punto de entrada de la app.
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/session.dart';
import 'screens/welcome_auth.dart';
import 'screens/home.dart';

void main() {
  runApp(const SipiApp());
}

class SipiApp extends StatefulWidget {
  const SipiApp({super.key});
  @override
  State<SipiApp> createState() => _SipiAppState();
}

class _SipiAppState extends State<SipiApp> {
  late final Session _session;

  @override
  void initState() {
    super.initState();
    _session = Session();
    _session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sipi',
      debugShowCheckedModeBanner: false,
      theme: sipiTheme(),
      home: _session.loggedIn
          ? MainShell(session: _session)
          : WelcomeScreen(session: _session),
    );
  }
}
