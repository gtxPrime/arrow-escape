import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';

void main() {
  test('Debug Level 232 generation', () {
    print('Starting generation debug for Level 232...');
    final level = LevelGenerator.generateLevel(232);
    print('Generation finished.');
    print('Pattern name: ${level.patternName}');
    print('Grid size: ${level.gridSize}');
    print('Arrows count: ${level.arrows.length}');
    print('Orphan dots count: ${level.orphanDots.length}');
    print('Solvable: ${level.solutionOrder != null}');

    // If it fell back to fallback, level.patternName will be 'fallback'
    expect(level.patternName, isNot('fallback'));
  });
}
