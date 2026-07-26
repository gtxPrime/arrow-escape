import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';

void main() {
  test('Update Tutorial Levels 1-3 with 2-dot arrows, verify solvability, and rebuild levels.bin', () {
    // 1. Generate and verify Levels 1, 2, 3
    final chunk1File = File('assets/verify_progress_chunk_1.json');
    expect(chunk1File.existsSync(), isTrue);
    final Map<String, dynamic> chunk1Data = jsonDecode(chunk1File.readAsStringSync());

    final progressFile = File('assets/verify_progress.json');
    Map<String, dynamic>? progressData;
    if (progressFile.existsSync()) {
      progressData = jsonDecode(progressFile.readAsStringSync());
    }

    for (int lvlNumber = 1; lvlNumber <= 3; lvlNumber++) {
      final lvl = LevelGenerator.generateLevel(lvlNumber);
      expect(lvl.levelNumber, equals(lvlNumber));

      // Verify no 1-dot arrows exist in tutorial levels
      for (final arrow in lvl.arrows) {
        expect(arrow.path.length, greaterThanOrEqualTo(2),
            reason: 'Level $lvlNumber arrow ${arrow.id} must have at least 2 dots (no 1-dot arrows allowed)');
      }

      // Verify solvability
      final solution = LevelSolver.solve(lvl);
      expect(solution, isNotNull, reason: 'Level $lvlNumber must be solvable');
      print('Level $lvlNumber Solution order: $solution');

      chunk1Data[lvlNumber.toString()] = {
        'status': 'pass',
        'ms': 1,
        'level': lvl.toJson(),
      };

      if (progressData != null) {
        progressData[lvlNumber.toString()] = {
          'status': 'pass',
          'ms': 1,
          'level': lvl.toJson(),
        };
      }
    }

    chunk1File.writeAsStringSync(jsonEncode(chunk1Data));
    if (progressFile.existsSync() && progressData != null) {
      progressFile.writeAsStringSync(jsonEncode(progressData));
    }

    // 2. Merge all chunk progress files & rebuild assets/levels.bin
    final mergedProgress = <String, dynamic>{};
    for (int chunk = 1; chunk <= 5; chunk++) {
      final file = File('assets/verify_progress_chunk_$chunk.json');
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        mergedProgress.addAll(data);
      }
    }

    final levels = <LevelModel>[];
    for (int lvl = 1; lvl <= 500; lvl++) {
      final entry = mergedProgress[lvl.toString()] as Map<String, dynamic>;
      final levelMap = entry['level'] as Map<String, dynamic>;
      levels.add(LevelModel.fromJson(levelMap));
    }

    levels.sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
    final bytes = encodeLevels(levels);
    File('assets/levels.bin').writeAsBytesSync(bytes);
    print('Rebuilt assets/levels.bin: ${bytes.length} bytes');

    // 3. Decode Level 2 from updated assets/levels.bin to verify
    final binBytes = File('assets/levels.bin').readAsBytesSync();
    final decoder = LevelBinaryDecoder.fromBytes(binBytes);
    final decodedL2 = decoder.decodeLevelByNumber(2);
    expect(decodedL2, isNotNull);
    for (final arrow in decodedL2!.arrows) {
      expect(arrow.path.length, greaterThanOrEqualTo(2),
          reason: 'Decoded Level 2 in levels.bin must have at least 2 dots per arrow');
    }
    final decodedColors = decodedL2.arrows.where((a) => a.colorGroup != null).toList();
    expect(decodedColors.length, equals(2), reason: 'Decoded Level 2 in levels.bin must have colored pair arrows');
    expect(decodedColors[0].colorGroup, equals(0));
    expect(decodedColors[1].colorGroup, equals(0));
  });
}
