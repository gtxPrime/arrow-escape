// ignore_for_file: avoid_print
// GENERATED -- do not edit directly. See gen_chunk_helper.dart for logic.
import 'package:flutter_test/flutter_test.dart';
import 'gen_chunk_helper.dart';

void main() {
  test('Generate levels 1-100 (chunk 1)', () {
    runChunk(
      startLevel: 1,
      endLevel:   100,
      cacheFile:  'assets/level_chunks/chunk_1.json',
      logFile:    'assets/level_chunks/chunk_1_log.txt',
    );
  });
}
