// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'verify_chunk_helper.dart';

void main() {
  test('Verify levels 401-500 (chunk 5)', () {
    runVerifyChunk(
      startLevel: 401,
      endLevel:   500,
      logFile:    'assets/chunk_5_log.txt',
    );
  });
}
