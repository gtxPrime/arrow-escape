import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/core/constants.dart';

void main() {
  print("Starting generator checks...");
  for (int i = 1; i <= 50; i++) {
    final sw = Stopwatch()..start();
    final type = AppConstants.levelTypeFor(i);
    print("Generating level $i ($type)...");
    final level = LevelGenerator.generateLevel(i);
    sw.stop();
    print("Generated level $i in ${sw.elapsedMilliseconds}ms. Grid: ${level.gridSize}, Arrows: ${level.arrows.length}");
    
    if (level.gridSize <= 15) {
      final swSolve = Stopwatch()..start();
      print("Solving level $i...");
      final solution = LevelSolver.solve(level);
      swSolve.stop();
      if (solution == null) {
        print("Level $i is UNSOLVABLE!");
      } else {
        print("Solved level $i in ${swSolve.elapsedMilliseconds}ms. Solution length: ${solution.length}");
      }
    }
  }
  print("All done!");
}
