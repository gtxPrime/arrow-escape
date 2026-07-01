// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/data/level_generator/level_generator.dart';
import 'package:arrow_puzzle/data/level_binary_codec.dart';

/// Round-trip test: generate levels, encode to binary, decode, verify correctness.
///
/// Run from project root:
///   flutter test test/binary_codec_test.dart -r expanded
void main() {
  test('Binary codec round-trip: encode then decode produces identical levels', () {
    print('Binary codec round-trip test');
    print('────────────────────────────');

    final testLevelNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 50, 100, 250, 500];
    int passed = 0;
    int failed = 0;

    for (final n in testLevelNumbers) {
      final original = LevelGenerator.generateLevel(n);

      // Encode this single level into binary
      final encoded = encodeLevels([original]);
      expect(encoded.length, greaterThan(8), reason: 'Encoded must have header');

      // Decode it back
      final decoder = LevelBinaryDecoder.fromBytes(encoded);
      expect(decoder.levelCount, equals(1));
      final decoded = decoder.decodeLevelByNumber(1);
      expect(decoded, isNotNull, reason: 'Level $n must decode');

      final d = decoded!;
      final issues = <String>[];

      if (d.levelNumber != original.levelNumber) {
        issues.add('levelNumber: ${d.levelNumber} != ${original.levelNumber}');
      }
      if (d.gridSize != original.gridSize) {
        issues.add('gridSize: ${d.gridSize} != ${original.gridSize}');
      }
      if (d.maskShape != original.maskShape) {
        issues.add('maskShape: ${d.maskShape} != ${original.maskShape}');
      }
      if (d.difficulty != original.difficulty) {
        issues.add('difficulty: ${d.difficulty} != ${original.difficulty}');
      }
      if (d.patternName != original.patternName) {
        issues.add('patternName: "${d.patternName}" != "${original.patternName}"');
      }
      if (d.arrows.length != original.arrows.length) {
        issues.add('arrowCount: ${d.arrows.length} != ${original.arrows.length}');
      }
      if (d.mask.length != original.mask.length) {
        issues.add('maskSize: ${d.mask.length} != ${original.mask.length}');
      } else {
        final missing = original.mask.difference(d.mask);
        if (missing.isNotEmpty) {
          issues.add('mask cells missing: ${missing.take(3)}');
        }
      }
      if (d.orphanDots.length != original.orphanDots.length) {
        issues.add('orphanDots: ${d.orphanDots.length} != ${original.orphanDots.length}');
      }
      if (d.solutionOrder.length != original.solutionOrder.length) {
        issues.add('solutionOrder len: ${d.solutionOrder.length} != ${original.solutionOrder.length}');
      }

      // Verify arrow paths
      for (int i = 0; i < original.arrows.length && i < d.arrows.length; i++) {
        final oa = original.arrows[i];
        final da = d.arrows[i];
        if (oa.direction != da.direction) {
          issues.add('arrow[$i] direction: ${da.direction} != ${oa.direction}');
        }
        if (oa.mechanic != da.mechanic) {
          issues.add('arrow[$i] mechanic: ${da.mechanic} != ${oa.mechanic}');
        }
        if (oa.isPartOfPattern != da.isPartOfPattern) {
          issues.add('arrow[$i] isPartOfPattern: ${da.isPartOfPattern} != ${oa.isPartOfPattern}');
        }
        if (oa.path.length != da.path.length) {
          issues.add('arrow[$i] pathLen: ${da.path.length} != ${oa.path.length}');
        } else {
          for (int j = 0; j < oa.path.length; j++) {
            if (oa.path[j][0] != da.path[j][0] || oa.path[j][1] != da.path[j][1]) {
              issues.add('arrow[$i] path[$j]: ${da.path[j]} != ${oa.path[j]}');
              break;
            }
          }
        }
      }

      if (issues.isEmpty) {
        print('  PASS level $n  [${original.patternName}]  '
            '${original.arrows.length} arrows  ${original.gridSize}×${original.gridSize}');
        passed++;
      } else {
        print('  FAIL level $n: ${issues.join('; ')}');
        failed++;
        for (final issue in issues) {
          fail('Level $n: $issue');
        }
      }
    }

    print('');
    print('Results: $passed passed, $failed failed');

    // Size check if both files exist
    if (File('assets/levels.bin').existsSync() && File('assets/levels.json').existsSync()) {
      final binKb = File('assets/levels.bin').lengthSync() / 1024;
      final jsonKb = File('assets/levels.json').lengthSync() / 1024;
      print('');
      print('File sizes:');
      print('  levels.json: ${jsonKb.toStringAsFixed(0)} KB');
      print('  levels.bin:  ${binKb.toStringAsFixed(0)} KB');
      print('  Ratio: ${(jsonKb / binKb).toStringAsFixed(1)}× smaller');
    }

    expect(failed, equals(0), reason: 'All codec round-trip tests must pass');
  });
}
