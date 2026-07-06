// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';

void main() {
  test('Build levels.bin from cached progress', () {
    print('');
    print('=====================================================');
    print(' Arrow Escape — Build levels.bin');
    print('=====================================================');
    print('');

    const totalLevels = 500;
    const outputFile = 'assets/levels.bin';

    // 1. Load and merge all chunk progress files.
    final rawProgress = <String, dynamic>{};
    for (int chunk = 1; chunk <= 5; chunk++) {
      final progressFile = 'assets/verify_progress_chunk_$chunk.json';
      final progressF = File(progressFile);
      if (progressF.existsSync()) {
        try {
          final chunkProgress = jsonDecode(progressF.readAsStringSync()) as Map<String, dynamic>;
          rawProgress.addAll(chunkProgress);
        } catch (e) {
          print('WARNING: Failed to parse $progressFile: $e');
        }
      }
    }


    // 2. Check all levels are passing and have cached JSON.
    final failing = <int>[];
    final missing = <int>[];
    final noJson  = <int>[];

    for (int lvl = 1; lvl <= totalLevels; lvl++) {
      final key = lvl.toString();
      if (!rawProgress.containsKey(key)) {
        missing.add(lvl);
      } else {
        final entry = rawProgress[key] as Map<String, dynamic>;
        if (entry['status'] != 'pass') {
          failing.add(lvl);
        } else if (!entry.containsKey('level')) {
          noJson.add(lvl);
        }
      }
    }

    if (missing.isNotEmpty || failing.isNotEmpty || noJson.isNotEmpty) {
      print('Cannot build levels.bin — some levels are not ready.');
      if (missing.isNotEmpty) {
        print('  Not yet run (${missing.length}): ${missing.take(20).join(", ")}${missing.length > 20 ? " ..." : ""}');
      }
      if (failing.isNotEmpty) {
        print('  Failing    (${failing.length}): ${failing.take(20).join(", ")}${failing.length > 20 ? " ..." : ""}');
      }
      if (noJson.isNotEmpty) {
        print('  Missing JSON (${noJson.length}): ${noJson.take(20).join(", ")}${noJson.length > 20 ? " ..." : ""}');
      }
      fail('Some levels failed, are missing, or lack cached JSON.');
    }

    // 3. Decode all levels from cached JSON — no re-generation needed.
    print('Reading $totalLevels cached levels from chunk progress files...');
    final levels = <LevelModel>[];

    final sw = Stopwatch()..start();

    for (int lvl = 1; lvl <= totalLevels; lvl++) {
      final entry    = rawProgress[lvl.toString()] as Map<String, dynamic>;
      final levelMap = entry['level'] as Map<String, dynamic>;
      levels.add(LevelModel.fromJson(levelMap));

      if (lvl % 100 == 0) {
        print('  Loaded $lvl / $totalLevels levels');
      }
    }

    sw.stop();
    print('Loaded in ${sw.elapsedMilliseconds}ms');
    print('');

    // 4. Sort (should already be in order, but be safe).
    levels.sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

    // 5. Encode to binary.
    print('Encoding to binary...');
    final encodeSw = Stopwatch()..start();
    final bytes = encodeLevels(levels);
    encodeSw.stop();

    // 6. Write.
    Directory('assets').createSync(recursive: true);
    File(outputFile).writeAsBytesSync(bytes);

    final kb = (bytes.length / 1024).toStringAsFixed(1);
    print('Written: $outputFile ($kb KB, ${bytes.length} bytes)');
    print('Encoding: ${encodeSw.elapsedMilliseconds}ms');
    print('');
    print('Done! assets/levels.bin is ready for the app.');
    print('');
  });
}
