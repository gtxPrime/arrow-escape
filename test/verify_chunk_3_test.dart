// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'verify_chunk_helper.dart';

void main() {
  test('Verify levels 201-300 (chunk 3)', () {
    runVerifyChunk(
      startLevel: 201,
      endLevel:   300,
      logFile:    'assets/chunk_3_log.txt',
    );
  });
}
