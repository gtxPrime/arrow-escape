import 'dart:io';
import '../lib/data/level_generator/level_generator.dart';
import '../lib/data/level_binary_codec.dart';
import '../lib/data/models/level.dart';

void main() {
  print('──────────────────────────────────────────────');
  print(' Arrow Puzzle — Standalone Level Pre-generator');
  print('──────────────────────────────────────────────');

  const totalLevels = 500;
  final levels = <LevelModel>[];
  final sw = Stopwatch()..start();

  for (int i = 1; i <= totalLevels; i++) {
    final levelSw = Stopwatch()..start();
    final level = LevelGenerator.generateLevel(i);
    levelSw.stop();

    levels.add(level);

    final isBossOrGod = level.patternName.startsWith('Boss') ||
        level.patternName.startsWith('God');
    if (isBossOrGod || i % 25 == 0 || i == totalLevels) {
      final ms = levelSw.elapsedMilliseconds;
      final timeStr =
          ms > 1000 ? '${(ms / 1000).toStringAsFixed(1)}s' : '${ms}ms';
      print(
          'Level ${'$i'.padLeft(3)} / $totalLevels  '
          '[${level.patternName.padRight(12)}]  '
          '${level.arrows.length.toString().padLeft(3)} arrows  '
          '${level.gridSize}×${level.gridSize}  '
          '$timeStr');
    }
  }

  sw.stop();
  print('');
  print('Generation complete: ${sw.elapsed.inSeconds}s for $totalLevels levels');

  // Encode to binary
  print('Encoding to binary...');
  final encodeSw = Stopwatch()..start();
  final bytes = encodeLevels(levels);
  encodeSw.stop();

  final outPath = 'assets/levels.bin';
  // Ensure assets directory exists
  final dir = Directory('assets');
  if (!dir.existsSync()) {
    dir.createSync();
  }
  
  File(outPath).writeAsBytesSync(bytes);

  final kbSize = (bytes.length / 1024).toStringAsFixed(1);
  print('Written: $outPath (${kbSize} KB, ${bytes.length} bytes)');
  print('Encoding time: ${encodeSw.elapsedMilliseconds}ms');
  print('Done! ✓');
}
