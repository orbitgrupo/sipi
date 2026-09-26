// Sipi — Términos de uso y Política de privacidad.
import 'package:flutter/material.dart';
import '../core/theme.dart';

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);
}

class _LegalScreen extends StatelessWidget {
  final String title;
  final String updated;
  final List<_LegalSection> sections;
  const _LegalScreen(
      {required this.title, required this.updated, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Última actualización: $updated',
              style: const TextStyle(color: SipiColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
          for (final s in sections) ...[
            Text(s.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: SipiColors.text)),
            const SizedBox(height: 6),
            Text(s.body,
                style: const TextStyle(
                    color: SipiColors.muted, fontSize: 14, height: 1.6)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Términos de uso',
      updated: '26 de septiembre de 2026',
      sections: [
        _LegalSection('1. Aceptación',
            'Al crear una cuenta o usar Sipi aceptas estos Términos de uso. Si no estás de acuerdo, no uses la aplicación.'),
        _LegalSection('2. Tu cuenta',
            'Debes registrarte con datos veraces y mantener tu contraseña en secreto. Las cuentas nuevas quedan pendientes de aprobación por nuestro equipo antes de operar con normalidad. Eres responsable de toda la actividad realizada con tu cuenta.'),
        _LegalSection('3. Cómo ganas puntos',
            'Ganas puntos completando tareas y encuestas. Los puntos solo se acreditan después de una verificación válida. Podemos rechazar envíos incompletos, duplicados o fraudulentos sin acreditar puntos.'),
        _LegalSection('4. Tareas de redes sociales',
            'Algunas tareas te piden seguir, interactuar o suscribirte en una red social. Para participar debes indicar tu usuario en esa red; nuestro equipo lo usa únicamente para verificar que realizaste la acción y luego aprobar tu recompensa. No estás obligado a participar en todas las redes: solo en las que elijas. Una vez aprobada, la tarea deja de mostrarse en tu lista porque ya la completaste.'),
        _LegalSection('5. Canjes',
            'Puedes canjear tus puntos según la conversión puntos→USD vigente en la aplicación. Los canjes los procesa nuestro equipo y pueden requerir una verificación adicional de identidad.'),
        _LegalSection('6. Conducta prohibida',
            'Queda prohibido crear cuentas múltiples, usar bots o automatizaciones, falsificar evidencias o manipular el sistema de puntos. Estas conductas pueden llevar a la suspensión o eliminación de la cuenta y a la pérdida de los puntos acumulados.'),
        _LegalSection('7. Disponibilidad del servicio',
            'Sipi se ofrece "tal cual". Hacemos lo posible por mantenerlo disponible, pero no garantizamos un funcionamiento ininterrumpido ni libre de errores.'),
        _LegalSection('8. Cambios en los términos',
            'Podemos actualizar estos términos cuando sea necesario. Te avisaremos en la aplicación cuando haya cambios importantes; seguir usando Sipi después del aviso implica tu aceptación.'),
        _LegalSection('9. Contacto',
            'Si tienes preguntas sobre estos términos, escríbenos desde la sección Soporte de la aplicación.'),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Política de privacidad',
      updated: '26 de septiembre de 2026',
      sections: [
        _LegalSection('1. Qué datos recogemos',
            'Recogemos tu nombre, correo electrónico y contraseña (almacenada de forma cifrada), tu historial de tareas, encuestas, canjes y puntos. Si participas en tareas de redes sociales, también recogemos el usuario que indiques en cada red.'),
        _LegalSection('2. Para qué usamos tus datos',
            'Usamos tus datos para operar Sipi: gestionar tu cuenta, acreditar tus puntos, procesar tus canjes y verificar tus tareas. Tu usuario en redes sociales se usa EXCLUSIVAMENTE para verificar que completaste la tarea correspondiente: no se comparte con terceros, no se usa con fines publicitarios y no se cruza con otros fines.'),
        _LegalSection('3. Con quién compartimos tus datos',
            'No vendemos tus datos personales. Solo los compartimos con los proveedores estrictamente necesarios para operar el servicio (por ejemplo, alojamiento), siempre bajo acuerdos de confidencialidad.'),
        _LegalSection('4. Conservación y eliminación',
            'Conservamos tus datos mientras tu cuenta esté activa. Puedes pedir en cualquier momento la corrección o eliminación de tus datos desde Soporte. Si eliminas tu cuenta, también se eliminan los usuarios de redes sociales que hayas proporcionado.'),
        _LegalSection('5. Seguridad',
            'Protegemos tus datos con cifrado y acceso restringido a nuestro equipo. Ningún sistema es infalible, pero aplicamos medidas razonables para evitar accesos no autorizados.'),
        _LegalSection('6. Tus derechos',
            'Tienes derecho a acceder, corregir y eliminar tus datos personales, y a retirar tu consentimiento cuando quieras. Escríbenos desde Soporte para ejercer estos derechos.'),
        _LegalSection('7. Menores',
            'Sipi no está dirigido a menores de 13 años. Si detectamos una cuenta de un menor de esa edad, la cerraremos y eliminaremos sus datos.'),
        _LegalSection('8. Cambios en esta política',
            'Podemos actualizar esta política para reflejar cambios en el servicio o en la ley. Te avisaremos en la aplicación cuando haya cambios importantes.'),
        _LegalSection('9. Contacto',
            'Para cualquier duda sobre tu privacidad, escríbenos desde la sección Soporte de la aplicación.'),
      ],
    );
  }
}
