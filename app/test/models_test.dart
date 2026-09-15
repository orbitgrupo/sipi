// Sipi — tests unitarios de modelos y reglas de negocio del cliente.
// No requieren backend ni emulador.
import 'package:flutter_test/flutter_test.dart';
import 'package:sipi/core/models.dart';
import 'package:sipi/widgets/common.dart' show taskIcon;

void main() {
  group('Balance', () {
    test('calcula nivel desde puntos ganados', () {
      final b = Balance.fromJson({
        'points': 1250,
        'pending_points': 50,
        'earned_points': 1200,
        'used_points': 0,
        'usd': 24.0,
        'level': 2,
        'points_per_usd': 50,
      });
      expect(b.level, 2);
      expect(b.usd, 24.0);
    });

    test('usa 50 puntos por USD por defecto cuando el servidor no lo envía', () {
      final b = Balance.fromJson({
        'points': 100,
        'pending_points': 0,
        'earned_points': 100,
        'used_points': 0,
        'usd': 2.0,
      });
      expect(b.pointsPerUsd, 50);
    });
  });

  group('Task', () {
    test('parsea iconos por categoría', () {
      expect(taskIcon('social'), isNotNull);
      expect(taskIcon('encuestas'), isNotNull);
      expect(taskIcon('productos'), isNotNull);
      expect(taskIcon('opinion'), isNotNull);
      expect(taskIcon('promociones'), isNotNull);
    });

    test('parsea campos con valores por defecto', () {
      final t = Task.fromJson({'id': 1, 'title': 'Seguir cuenta', 'points': 10});
      expect(t.category, 'otras');
      expect(t.estimatedMinutes, 5);
    });
  });

  group('Survey', () {
    test('parsea preguntas de todos los tipos', () {
      final s = Survey.fromJson({
        'id': 1,
        'title': 'Opinión',
        'answered': false,
        'questions': [
          {'id': 'q1', 'type': 'single', 'text': '¿Cuál?', 'options': ['a', 'b']},
          {'id': 'q2', 'type': 'multiple', 'text': '¿Cuáles?', 'options': ['a']},
          {'id': 'q3', 'type': 'yesno', 'text': '¿Sí?'},
          {'id': 'q4', 'type': 'scale', 'text': 'Del 1 al 5', 'min': 1, 'max': 5},
          {'id': 'q5', 'type': 'text', 'text': 'Cuéntanos'},
        ],
      });
      expect(s.questions.length, 5);
      expect(s.questions[3].min, 1);
      expect(s.questions[3].max, 5);
    });
  });

  group('LedgerMovement', () {
    test('parsea movimientos con nota', () {
      final m = LedgerMovement.fromJson({
        'id': 1,
        'type': 'BONUS',
        'points': 50,
        'note': 'Logro: Primera tarea',
        'created_at': '2026-09-14T03:00:00Z',
      });
      expect(m.points, 50);
      expect(m.type, 'BONUS');
    });
  });
}
