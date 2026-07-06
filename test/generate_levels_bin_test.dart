// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';

/// Generates all 500 levels and writes them to assets/levels.bin
/// in a compact binary format.
///
/// Run from project root:
///   flutter test test/generate_levels_bin_test.dart -r expanded
void main() {
  test('Generate and encode all 500 levels to assets/levels.bin', () {
    print('──────────────────────────────────────────────');
    print(' Arrow Puzzle — Binary Level Pre-generator');
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
    File(outPath).writeAsBytesSync(bytes);

    final kbSize = (bytes.length / 1024).toStringAsFixed(1);
    print('Written: $outPath (${kbSize} KB, ${bytes.length} bytes)');
    print('Encoding time: ${encodeSw.elapsedMilliseconds}ms');

    // Compare to JSON if present
    final jsonFile = File('assets/levels.json');
    if (jsonFile.existsSync()) {
      final jsonKb = (jsonFile.lengthSync() / 1024).toStringAsFixed(1);
      final ratio = (jsonFile.lengthSync() / bytes.length).toStringAsFixed(1);
      print('');
      print('Size comparison:');
      print('  levels.json : $jsonKb KB');
      print('  levels.bin  : $kbSize KB');
      print('  Reduction   : ${ratio}× smaller ✓');
    }

    print('');
    print('Done! ✓');
  });
}
