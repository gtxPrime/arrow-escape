// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'verify_chunk_helper.dart';

void main() {
  test('Verify levels 301-400 (chunk 4)', () {
    runVerifyChunk(
      startLevel: 301,
      endLevel:   400,
      logFile:    'assets/chunk_4_log.txt',
    );
  });
}
