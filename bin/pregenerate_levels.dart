import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/data/level_generator/level_generator.dart';

void main() {
  test('Pre-generate all 500 game levels and save to JSON', () {
    print('Starting pre-generation of all 500 levels...');
    final sw = Stopwatch()..start();
    final Map<String, dynamic> levelsJson = {};

    for (int i = 1; i <= 500; i++) {
      final levelSw = Stopwatch()..start();
      final level = LevelGenerator.generateLevel(i);
      levelSw.stop();
      
      levelsJson['$i'] = level.toJson();
      
      if (i % 25 == 0 || levelSw.elapsedMilliseconds > 200) {
        print('Generated level $i / 500 in ${levelSw.elapsedMilliseconds}ms...');
      }
    }

    sw.stop();
    print('Generation finished in ${sw.elapsed.inSeconds} seconds.');

    print('Saving to assets/levels.json...');
    final File file = File('assets/levels.json');
    file.writeAsStringSync(jsonEncode(levelsJson));
    print('Successfully saved ${levelsJson.length} levels to assets/levels.json.');
  });
}
