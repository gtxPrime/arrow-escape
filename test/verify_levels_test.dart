import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'verify_helpers.dart';

void main() {
  test('Verify Chunk 1 (levels 160 to 228)', () {
    verifyLevelRange(160, 228, 'verify_chunk1.txt');
  }, timeout: Timeout(Duration(minutes: 30)));

  test('Arrow length distribution roughly matches the 3-tier adaptive target', () {
    int veryLongCount = 0;
    int longCount = 0;
    int medCount = 0;

    for (int i = 160; i <= 220; i++) {
      final level = LevelGenerator.generateLevel(i);
      final gs = level.gridSize;
      final vlMin = 5 + (gs ~/ 6);
      final lMin  = 3 + (gs ~/ 10);
      for (final arrow in level.arrows) {
        final len = arrow.path.length;
        if (len >= vlMin) veryLongCount++;
        else if (len >= lMin) longCount++;
        else if (len >= 3) medCount++;
      }
    }

    final total = veryLongCount + longCount + medCount;
    if (total > 0) {
      final vlPct = veryLongCount / total * 100;
      final lPct = longCount / total * 100;
      final medPct = medCount / total * 100;
      expect(vlPct, greaterThan(15), reason: 'Very Long arrows too few: $vlPct%');
      expect(vlPct, lessThan(50), reason: 'Very Long arrows too many: $vlPct%');
      expect(lPct, greaterThan(15), reason: 'Long arrows too few: $lPct%');
      expect(lPct, lessThan(50), reason: 'Long arrows too many: $lPct%');
      expect(medPct, greaterThan(15), reason: 'Medium arrows too few: $medPct%');
    }
  });
}
