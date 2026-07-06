import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';

void main() {
  test('Trace Level Generation Progress', () {
    final logFile = File('gen_progress_log.txt');
    logFile.writeAsStringSync('Starting trace...\n');

    for (int i = 1; i <= 50; i++) {
      logFile.appendTextSync('Generating level $i...\n');
      final s = Stopwatch()..start();
      final level = LevelGenerator.generateLevel(i);
      s.stop();
      logFile.appendTextSync('Level $i generated in ${s.elapsedMilliseconds} ms. Grid: ${level.gridSize}, Arrows: ${level.arrows.length}, Orphans: ${level.orphanDots.length}\n');
    }
    logFile.appendTextSync('Trace completed successfully!\n');
  });
}

extension FileAppend on File {
  void appendTextSync(String text) {
    writeAsStringSync(text, mode: FileMode.append, flush: true);
  }
}
