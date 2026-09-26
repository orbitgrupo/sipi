import 'package:flutter/material.dart';

/// Nombres y textos de las redes sociales soportadas por las tareas sociales.
String socialNetworkName(String? network) {
  switch (network) {
    case 'instagram':
      return 'Instagram';
    case 'tiktok':
      return 'TikTok';
    case 'facebook':
      return 'Facebook';
    case 'x':
      return 'X';
    case 'youtube':
      return 'YouTube';
    default:
      return 'la red social';
  }
}

/// Verbo de la acción, p. ej. "Síguenos en Instagram".
String socialActionText(String? action, String? network) {
  final net = socialNetworkName(network);
  switch (action) {
    case 'follow':
      return 'Síguenos en $net';
    case 'like':
      return 'Dale me gusta en $net';
    case 'share':
      return 'Comparte en $net';
    case 'comment':
      return 'Comenta en $net';
    case 'subscribe':
      return 'Suscríbete en $net';
    default:
      return 'Participa en $net';
  }
}

IconData socialNetworkIcon(String? network) {
  switch (network) {
    case 'instagram':
      return Icons.camera_alt_outlined;
    case 'tiktok':
      return Icons.music_note_outlined;
    case 'facebook':
      return Icons.thumb_up_outlined;
    case 'x':
      return Icons.alternate_email;
    case 'youtube':
      return Icons.play_circle_outline;
    default:
      return Icons.share_outlined;
  }
}
