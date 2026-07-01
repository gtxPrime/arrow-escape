import 'dart:convert';
import 'dart:typed_data';
import 'models/arrow.dart';
import 'models/level.dart';

// ─── Binary Format Spec (v2) ──────────────────────────────────────────────────
//
// HEADER         (8 bytes)
//   4 bytes  magic: 0x4C 0x56 0x4C 0x42  ('LVLB')
//   2 bytes  version: uint16 = 2
//   2 bytes  levelCount: uint16
//
// INDEX TABLE    (levelCount × 4 bytes)
//   uint32   byte offset of each level's data, relative to start of DATA SECTION
//
// DATA SECTION   (variable)
//   For each level:
//     2 bytes  levelNumber (uint16)
//     1 byte   gridSize
//     1 byte   maskShape index
//     1 byte   difficulty index
//     1 byte   patternName length (in bytes)
//     N bytes  patternName (UTF-8)
//     2 bytes  arrowCount (uint16)
//
//     [ARROWS] × arrowCount
//       1 byte  row
//       1 byte  col
//       1 byte  packed: direction(2b) | mechanic(2b) | isPartOfPattern(1b) | reserved(3b)
//       1 byte  colorGroup (0xFF = null)
//       1 byte  pathStepCount  (steps AFTER the head cell)
//       pathStepCount bytes: step direction (0=up,1=down,2=left,3=right)
//
//     2 bytes  solutionOrderCount (uint16)
//     [SOLUTION ORDER] × solutionOrderCount bytes: arrow index (uint8)
//       NOTE: if arrowCount > 255 this would need uint16 — but in practice max is ~200
//
//     ceil(gridSize²/8) bytes: mask bitmask, row-major, MSB first
//
//     2 bytes  orphanDotCount (uint16)
//     [ORPHAN DOTS] × orphanDotCount × 3 bytes:
//       1 byte  row
//       1 byte  col
//       1 byte  type index
//
// ─────────────────────────────────────────────────────────────────────────────

const _kMagic = [0x4C, 0x56, 0x4C, 0x42]; // 'LVLB'
const _kVersion = 2;

// ─── Encoder ─────────────────────────────────────────────────────────────────

/// Encodes a list of [LevelModel] objects into a compact binary [Uint8List].
Uint8List encodeLevels(List<LevelModel> levels) {
  // 1. Encode each level individually, collect byte arrays.
  final encodedLevels = levels.map(_encodeLevel).toList();

  final headerSize = 8;
  final indexSize = levels.length * 4;
  final dataSize = encodedLevels.fold<int>(0, (sum, b) => sum + b.length);
  final totalSize = headerSize + indexSize + dataSize;

  final out = ByteData(totalSize);
  int pos = 0;

  // Header
  for (final b in _kMagic) {
    out.setUint8(pos++, b);
  }
  out.setUint16(pos, _kVersion, Endian.little);
  pos += 2;
  out.setUint16(pos, levels.length, Endian.little);
  pos += 2;

  // Index table — offsets relative to start of data section
  int dataOffset = 0;
  for (final encoded in encodedLevels) {
    out.setUint32(pos, dataOffset, Endian.little);
    pos += 4;
    dataOffset += encoded.length;
  }

  // Data section
  for (final encoded in encodedLevels) {
    for (int i = 0; i < encoded.length; i++) {
      out.setUint8(pos++, encoded[i]);
    }
  }

  return out.buffer.asUint8List();
}

Uint8List _encodeLevel(LevelModel level) {
  final buf = _ByteWriter();

  buf.writeUint16(level.levelNumber);
  buf.writeUint8(level.gridSize);
  buf.writeUint8(level.maskShape.index);
  buf.writeUint8(level.difficulty.index);
  buf.writeString(level.patternName);
  buf.writeUint16(level.arrows.length);

  for (final arrow in level.arrows) {
    buf.writeUint8(arrow.row);
    buf.writeUint8(arrow.col);

    // packed byte: direction(2b) | mechanic(2b) | isPartOfPattern(1b) | 0(3b)
    final packed = (arrow.direction.index & 0x3) |
        ((arrow.mechanic.index & 0x3) << 2) |
        ((arrow.isPartOfPattern ? 1 : 0) << 4);
    buf.writeUint8(packed);

    buf.writeUint8(arrow.colorGroup ?? 0xFF);

    // Path: head is at path[0], each subsequent step encoded as a delta direction.
    final steps = _encodePathSteps(arrow.path);
    buf.writeUint8(steps.length); // max path length ~255 in practice
    for (final s in steps) {
      buf.writeUint8(s);
    }
  }

  // Solution order: stored as arrow indices
  final arrowIdToIndex = <String, int>{};
  for (int i = 0; i < level.arrows.length; i++) {
    arrowIdToIndex[level.arrows[i].id] = i;
  }
  buf.writeUint16(level.solutionOrder.length);
  for (final id in level.solutionOrder) {
    buf.writeUint8(arrowIdToIndex[id] ?? 0);
  }

  // Mask as bitmask (row-major, MSB first within each byte)
  final gs = level.gridSize;
  final maskBitCount = gs * gs;
  final maskByteCount = (maskBitCount + 7) ~/ 8;
  final maskBytes = Uint8List(maskByteCount);
  for (final cell in level.mask) {
    final comma = cell.indexOf(',');
    final r = int.parse(cell.substring(0, comma));
    final c = int.parse(cell.substring(comma + 1));
    final bit = r * gs + c;
    maskBytes[bit >> 3] |= (0x80 >> (bit & 7));
  }
  buf.writeBytes(maskBytes);

  // Orphan dots
  buf.writeUint16(level.orphanDots.length);
  for (final dot in level.orphanDots) {
    buf.writeUint8(dot.row);
    buf.writeUint8(dot.col);
    buf.writeUint8(dot.type.index);
  }

  return buf.toBytes();
}

/// Converts path (list of [row,col] pairs) to delta step directions.
List<int> _encodePathSteps(List<List<int>> path) {
  final steps = <int>[];
  for (int i = 0; i < path.length - 1; i++) {
    final dr = path[i + 1][0] - path[i][0];
    final dc = path[i + 1][1] - path[i][1];
    if (dr == -1) steps.add(0);      // up
    else if (dr == 1) steps.add(1);  // down
    else if (dc == -1) steps.add(2); // left
    else steps.add(3);               // right
  }
  return steps;
}

// ─── Decoder ─────────────────────────────────────────────────────────────────

/// Decodes binary level data produced by [encodeLevels].
/// Provides O(1) random access to any level via an index table.
class LevelBinaryDecoder {
  final ByteData _data;
  final int _levelCount;
  final int _indexTableStart;
  final int _dataStart;

  LevelBinaryDecoder._(
      this._data, this._levelCount, this._indexTableStart, this._dataStart);

  /// Parse the header and construct the decoder. Throws on magic/version mismatch.
  factory LevelBinaryDecoder.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    // Validate magic bytes
    for (int i = 0; i < 4; i++) {
      if (data.getUint8(i) != _kMagic[i]) {
        throw const FormatException('Invalid levels.bin: bad magic');
      }
    }
    final version = data.getUint16(4, Endian.little);
    if (version != _kVersion) {
      throw FormatException('Unsupported levels.bin version: $version');
    }
    final levelCount = data.getUint16(6, Endian.little);
    const indexTableStart = 8;
    final dataStart = indexTableStart + levelCount * 4;
    return LevelBinaryDecoder._(data, levelCount, indexTableStart, dataStart);
  }

  int get levelCount => _levelCount;

  /// Decode a level by its 1-based level number. Returns null if out of range.
  LevelModel? decodeLevelByNumber(int levelNumber) {
    final idx = levelNumber - 1;
    if (idx < 0 || idx >= _levelCount) return null;
    return _decodeLevelAtIndex(idx);
  }

  /// Decode all levels eagerly (only for tools, not for device use).
  List<LevelModel> decodeAll() {
    return List.generate(_levelCount, _decodeLevelAtIndex);
  }

  LevelModel _decodeLevelAtIndex(int idx) {
    final offsetInData =
        _data.getUint32(_indexTableStart + idx * 4, Endian.little);
    final reader = _ByteReader(_data, _dataStart + offsetInData);
    return _decodeLevel(reader);
  }

  LevelModel _decodeLevel(_ByteReader r) {
    final levelNumber = r.readUint16();
    final gridSize = r.readUint8();
    final maskShape = MaskShape.values[
        r.readUint8().clamp(0, MaskShape.values.length - 1)];
    final difficulty = Difficulty.values[
        r.readUint8().clamp(0, Difficulty.values.length - 1)];
    final patternName = r.readString();
    final arrowCount = r.readUint16();

    final arrows = <ArrowModel>[];
    for (int i = 0; i < arrowCount; i++) {
      final row = r.readUint8();
      final col = r.readUint8();
      final packed = r.readUint8();
      final direction = ArrowDirection.values[packed & 0x3];
      final mechanic = SnakeMechanic.values[(packed >> 2) & 0x3];
      final isPartOfPattern = ((packed >> 4) & 0x1) == 1;
      final colorGroupRaw = r.readUint8();
      final colorGroup = colorGroupRaw == 0xFF ? null : colorGroupRaw;

      final stepCount = r.readUint8();
      final path = <List<int>>[
        [row, col]
      ];
      for (int s = 0; s < stepCount; s++) {
        final stepDir = r.readUint8();
        final last = path.last;
        switch (stepDir) {
          case 0:
            path.add([last[0] - 1, last[1]]);
            break; // up
          case 1:
            path.add([last[0] + 1, last[1]]);
            break; // down
          case 2:
            path.add([last[0], last[1] - 1]);
            break; // left
          default:
            path.add([last[0], last[1] + 1]);
            break; // right
        }
      }

      arrows.add(ArrowModel(
        id: 'a_${levelNumber}_$i',
        row: row,
        col: col,
        direction: direction,
        state: ArrowState.idle,
        isPartOfPattern: isPartOfPattern,
        mechanic: mechanic,
        colorGroup: colorGroup,
        path: path,
      ));
    }

    // Solution order — stored as arrow index bytes
    final solCount = r.readUint16();
    final solutionOrder = <String>[];
    for (int i = 0; i < solCount; i++) {
      final arrowIdx = r.readUint8();
      solutionOrder.add('a_${levelNumber}_$arrowIdx');
    }

    // Mask bitmask — row-major, MSB first
    final maskBitCount = gridSize * gridSize;
    final maskByteCount = (maskBitCount + 7) ~/ 8;
    final maskBytes = r.readBytes(maskByteCount);
    final mask = <String>{};
    for (int bit = 0; bit < maskBitCount; bit++) {
      if ((maskBytes[bit >> 3] & (0x80 >> (bit & 7))) != 0) {
        final row = bit ~/ gridSize;
        final col = bit % gridSize;
        mask.add('$row,$col');
      }
    }

    // Orphan dots
    final orphanCount = r.readUint16();
    final orphanDots = <OrphanDot>[];
    for (int i = 0; i < orphanCount; i++) {
      final row = r.readUint8();
      final col = r.readUint8();
      final type = OrphanDotType.values[
          r.readUint8().clamp(0, OrphanDotType.values.length - 1)];
      orphanDots.add(OrphanDot(row: row, col: col, type: type));
    }

    return LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: patternName,
      difficulty: difficulty,
      solutionOrder: solutionOrder,
      maskShape: maskShape,
      mask: mask,
      orphanDots: orphanDots,
    );
  }
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

class _ByteWriter {
  final List<int> _bytes = [];

  void writeUint8(int v) => _bytes.add(v & 0xFF);

  void writeUint16(int v) {
    _bytes.add(v & 0xFF);
    _bytes.add((v >> 8) & 0xFF);
  }

  /// Write a short UTF-8 string (length-prefixed, max 255 bytes).
  void writeString(String s) {
    final encoded = utf8.encode(s);
    writeUint8(encoded.length);
    _bytes.addAll(encoded);
  }

  void writeBytes(Uint8List bytes) => _bytes.addAll(bytes);

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

class _ByteReader {
  final ByteData _data;
  int _pos;

  _ByteReader(this._data, int start) : _pos = start;

  int readUint8() => _data.getUint8(_pos++);

  int readUint16() {
    final v = _data.getUint16(_pos, Endian.little);
    _pos += 2;
    return v;
  }

  /// Read a length-prefixed UTF-8 string.
  String readString() {
    final len = readUint8();
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _pos, len);
    _pos += len;
    return utf8.decode(bytes);
  }

  Uint8List readBytes(int count) {
    final bytes =
        _data.buffer.asUint8List(_data.offsetInBytes + _pos, count);
    _pos += count;
    return bytes;
  }
}
