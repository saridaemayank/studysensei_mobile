import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/features/sensei/services/sensei_image_preparation.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_error.dart';
import 'sensei_doubt_api_test.dart' show errorCode;

class InspectEncoder extends UnsupportedFlutterImageCompress {
  int calls = 0;
  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    calls++;
    expect(SenseiImagePreparation.mimeType(image), 'image/png');
    final codec = await ui.instantiateImageCodec(image);
    final decoded = (await codec.getNextFrame()).image;
    // The EXIF-rotated source was 120x160. The encoder must receive upright
    // 160x120 pixels, without upscaling or a second orientation correction.
    expect(decoded.width, 160);
    expect(decoded.height, 120);
    decoded.dispose();
    codec.dispose();
    expect(autoCorrectionAngle, isFalse);
    expect(rotate, 0);
    expect(keepExif, isFalse);
    return File('test/fixtures/preparation_upright.jpg').readAsBytesSync();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jpeg = File('test/fixtures/preparation.jpg').readAsBytesSync();
  for (final file in ['preparation.jpg', 'portrait.png', 'preparation.webp']) {
    test('Safe $file retains original XFile and bytes', () async {
      int conversions = 0;
      final prep = SenseiImagePreparation(convert: (bytes, edge) async {
        conversions++;
        return jpeg;
      });
      final original = XFile.fromData(
          File('test/fixtures/$file').readAsBytesSync(),
          name: file);
      expect(await prep.prepare(original), same(original));
      expect(conversions, 0);
    });
  }
  for (final brand in ['heic', 'heif', 'mif1']) {
    test('$brand conversion completes before selection handoff', () async {
      final heic = Uint8List.fromList(
          [0, 0, 0, 24, ...'ftyp${brand}00000000'.codeUnits]);
      int calls = 0;
      final prep = SenseiImagePreparation(
          inspectPixels: (_) async => 120 * 160,
          convert: (bytes, edge) async {
            calls++;
            expect(bytes, heic);
            expect(edge, 4096);
            return jpeg;
          });
      final original = XFile.fromData(heic, name: 'image.$brand');
      final prepared = await prep.prepare(original);
      expect(identical(prepared, original), isFalse);
      expect(calls, 1);
      expect(await prepared.readAsBytes(), jpeg);
      expect(prepared.mimeType, 'image/jpeg');
    });
  }
  test('Real decoder normalizes EXIF before native JPEG encoding', () async {
    final previous = FlutterImageCompressPlatform.instance;
    final encoder = InspectEncoder();
    FlutterImageCompressPlatform.instance = encoder;
    addTearDown(() => FlutterImageCompressPlatform.instance = previous);
    final source =
        File('test/fixtures/preparation_rotated.jpg').readAsBytesSync();
    final padded = Uint8List(SenseiImagePreparation.maxBytes + 1)
      ..setRange(0, source.length, source);
    final prepared =
        await SenseiImagePreparation().prepare(XFile.fromData(padded));
    expect(encoder.calls, 1);
    expect(await SenseiImagePreparation.pixels(await prepared.readAsBytes()),
        160 * 120);
  });
  test(
      '48 MP input is prepared; extreme dimensions are rejected before conversion',
      () async {
    int conversions = 0;
    final original = XFile.fromData(jpeg);
    final prepared = await SenseiImagePreparation(
        inspectPixels: (_) async => 48000000,
        convert: (_, _) async {
          conversions++;
          return jpeg;
        }).prepare(original);
    expect(identical(prepared, original), isFalse);
    expect(conversions, 1);
    await expectLater(
        SenseiImagePreparation(
            inspectPixels: (_) async => 100000000,
            convert: (_, _) async {
              conversions++;
              return jpeg;
            }).prepare(original),
        throwsA(errorCode(DoubtErrorCode.mediaProcessingFailed)));
    expect(conversions, 1);
  });
  test('Oversized supported image is prepared instead of passed through',
      () async {
    final oversized = Uint8List(SenseiImagePreparation.maxBytes + 1)
      ..setRange(0, jpeg.length, jpeg);
    int calls = 0;
    final prepared = await SenseiImagePreparation(convert: (bytes, edge) async {
      calls++;
      return jpeg;
    }).prepare(XFile.fromData(oversized));
    expect(calls, 1);
    expect(await prepared.length(), jpeg.length);
  });
  test('Unreadable and failed conversion produce safe typed errors', () async {
    await expectLater(
        SenseiImagePreparation()
            .prepare(XFile.fromData(Uint8List.fromList([1, 2, 3]))),
        throwsA(errorCode(DoubtErrorCode.imageUnreadable)));
    final heic =
        Uint8List.fromList([0, 0, 0, 24, ...'ftypheic00000000'.codeUnits]);
    await expectLater(
        SenseiImagePreparation(
                convert: (_, _) async => throw StateError('private path'))
            .prepare(XFile.fromData(heic)),
        throwsA(errorCode(DoubtErrorCode.mediaProcessingFailed)));
  });
  test('Still oversized output stops after bounded attempts', () async {
    final oversized = Uint8List(SenseiImagePreparation.maxBytes + 1)
      ..setRange(0, jpeg.length, jpeg);
    final edges = <int>[];
    await expectLater(
        SenseiImagePreparation(convert: (_, edge) async {
          edges.add(edge);
          return oversized;
        }).prepare(XFile.fromData(oversized)),
        throwsA(errorCode(DoubtErrorCode.mediaProcessingFailed)));
    expect(edges, [4096, 3072, 2048, 1536]);
  });
}
