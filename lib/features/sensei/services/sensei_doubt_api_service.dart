import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/sensei_doubt_error.dart';
import '../models/sensei_doubt_response.dart';
import '../models/sensei_help_request.dart';
import 'sensei_image_preparation.dart';

abstract interface class DoubtApi {
  Future<SenseiDoubtResponse> submit(SenseiHelpRequest request);
  void close();
}

class SenseiDoubtApiService implements DoubtApi {
  static final endpoint = Uri.parse(
      'https://us-central1-study-sensei-53462.cloudfunctions.net/api/sensei/doubt');
  final http.Client _client;
  final Future<String?> Function() _token;
  final Duration timeout;
  bool _closed = false;
  bool _busy = false;
  SenseiDoubtApiService(
      {http.Client? client,
      Future<String?> Function()? token,
      this.timeout = const Duration(seconds: 100)})
      : _client = client ?? http.Client(),
        _token = token ?? _firebaseToken;

  static Future<String?> _firebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken(true);
  }

  @override
  void close() {
    _closed = true;
    _client.close();
  }

  @override
  Future<SenseiDoubtResponse> submit(SenseiHelpRequest request) async {
    if (_closed) {
      throw const SenseiDoubtError(DoubtErrorCode.cancelled);
    }
    if (_busy) {
      throw const SenseiDoubtError(DoubtErrorCode.invalidRequest);
    }
    _busy = true;
    try {
      return await _submit(request).timeout(timeout);
    } on TimeoutException {
      // Close this transport so a timed-out upload cannot overlap a retry.
      close();
      throw const SenseiDoubtError(DoubtErrorCode.timeout);
    } on SenseiDoubtError {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw SenseiDoubtError(e.code == 'network-request-failed'
          ? DoubtErrorCode.network
          : DoubtErrorCode.unauthorized);
    } on http.ClientException {
      throw SenseiDoubtError(
          _closed ? DoubtErrorCode.cancelled : DoubtErrorCode.network);
    } catch (_) {
      throw const SenseiDoubtError(DoubtErrorCode.internalError);
    } finally {
      _busy = false;
    }
  }

  Future<SenseiDoubtResponse> _submit(SenseiHelpRequest request) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const SenseiDoubtError(DoubtErrorCode.unauthorized);
    }
    final region = request.imageSelection.focusRegion;
    if (request.userPrompt != null && request.userPrompt!.length > 2000 ||
        region.toJson().values.any((v) => !v.isFinite || v < 0 || v > 1) ||
        region.width <= 0 ||
        region.height <= 0 ||
        region.x + region.width > 1 + 1e-9 ||
        region.y + region.height > 1 + 1e-9) {
      throw const SenseiDoubtError(DoubtErrorCode.invalidRequest);
    }
    final image = request.imageSelection.image;
    if (await image.length() > SenseiImagePreparation.maxBytes) {
      throw const SenseiDoubtError(DoubtErrorCode.invalidRequest);
    }
    final bytes = await image.readAsBytes();
    final mime = SenseiImagePreparation.mimeType(bytes);
    if (mime == null ||
        await SenseiImagePreparation.pixels(bytes) >
            SenseiImagePreparation.maxPixels) {
      throw const SenseiDoubtError(DoubtErrorCode.imageUnreadable);
    }
    if (_closed) {
      throw const SenseiDoubtError(DoubtErrorCode.cancelled);
    }
    final multipart = http.MultipartRequest('POST', endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll({
        'focusRegion': jsonEncode(region.toJson()),
        'helpMode': request.mode.apiValue,
        'academicLevel': request.academicLevel.apiValue,
        if (request.userPrompt?.isNotEmpty == true)
          'userPrompt': request.userPrompt!,
      })
      ..files.add(http.MultipartFile.fromBytes('image', bytes,
          filename: 'sensei.${mime.split('/').last}',
          contentType: MediaType.parse(mime)));
    final response =
        await http.Response.fromStream(await _client.send(multipart));
    if (_closed) {
      throw const SenseiDoubtError(DoubtErrorCode.cancelled);
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } catch (_) {
      throw SenseiDoubtError(response.statusCode == 401
          ? DoubtErrorCode.unauthorized
          : DoubtErrorCode.malformedResponse);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json is Map ? json['error'] : null;
      final code = error is Map ? error['code'] : null;
      throw SenseiDoubtError(response.statusCode == 401
          ? DoubtErrorCode.unauthorized
          : DoubtErrorCode.fromBackend(code is String ? code : null));
    }
    final result = SenseiDoubtResponse.fromJson(json);
    if (result.mode != request.mode) {
      throw const SenseiDoubtError(DoubtErrorCode.malformedResponse);
    }
    return result;
  }
}
