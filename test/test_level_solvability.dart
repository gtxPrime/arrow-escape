import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';

void main() {
  test('Test Level 160 Solvability under huge cap', () {
    final level = LevelGenerator.generateLevel(160);
    print('Level 160: Grid=' +
        level.gridSize.toString() +
        ', Arrows=' +
        level.arrows.length.toString());

    final stopwatch = Stopwatch()..start();
    final solution = LevelSolver.solve(level, 5000000);
    stopwatch.stop();

    if (solution != null) {
      print('SOLVABLE! Found solution of length ' +
          solution.length.toString() +
          ' in ' +
          stopwatch.elapsedMilliseconds.toString() +
          'ms');
    } else {
      print('UNSOLVABLE even with 5,000,000 states! Taken ' +
          stopwatch.elapsedMilliseconds.toString() +
          'ms');
    }
  });
}
