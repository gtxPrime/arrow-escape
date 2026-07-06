// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'verify_chunk_helper.dart';

void main() {
  test('Verify levels 1-100 (chunk 1)', () {
    runVerifyChunk(
      startLevel: 1,
      endLevel:   100,
      logFile:    'assets/chunk_1_log.txt',
    );
  });
}
