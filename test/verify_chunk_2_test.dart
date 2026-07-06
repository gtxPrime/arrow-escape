// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'verify_chunk_helper.dart';

void main() {
  test('Verify levels 101-200 (chunk 2)', () {
    runVerifyChunk(
      startLevel: 101,
      endLevel:   200,
      logFile:    'assets/chunk_2_log.txt',
    );
  });
}
