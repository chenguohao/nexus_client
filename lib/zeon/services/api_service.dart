import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            (Platform.isAndroid
                ? 'http://10.0.2.2:8080'
                : 'http://127.0.0.1:8080');

  Future<String> getChallenge(String deviceFingerprint) async {
    final uri = Uri.parse('$baseUrl/get-challenge')
        .replace(queryParameters: {'device_fingerprint': deviceFingerprint});
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    _assertOk(response, 'get-challenge');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final challenge = json['challenge'] as String?;
    if (challenge == null || challenge.isEmpty) {
      throw ApiException('Empty challenge returned from server');
    }
    return challenge;
  }

  Future<SubmitMiningResponse> submitMining({
    required String challenge,
    required String nonce,
    required String hash,
    required String publicKey,
    required String signature,
  }) async {
    final uri = Uri.parse('$baseUrl/submit-mining');
    final body = jsonEncode({
      'challenge': challenge,
      'nonce': nonce,
      'hash': hash,
      'public_key': publicKey,
      'signature': signature,
    });
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));
    _assertOk(response, 'submit-mining');
    return SubmitMiningResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<QuickAuthResponse> quickRegister({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/quick-register');
    final body = jsonEncode({'username': username, 'password': password});
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    _assertOk(response, 'quick-register');
    return QuickAuthResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<QuickAuthResponse> quickLogin({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/quick-login');
    final body = jsonEncode({'username': username, 'password': password});
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    _assertOk(response, 'quick-login');
    return QuickAuthResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _assertOk(http.Response response, String endpoint) {
    if (response.statusCode != 200) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        message = json['error'] as String? ?? message;
      } catch (_) {}
      throw ApiException('[$endpoint] $message');
    }
  }
}

class SubmitMiningResponse {
  final String walletAddress;
  final String uid;
  final String matrixUserId;
  final String matrixAccessToken;
  final String deviceId;

  const SubmitMiningResponse({
    required this.walletAddress,
    required this.uid,
    required this.matrixUserId,
    required this.matrixAccessToken,
    required this.deviceId,
  });

  factory SubmitMiningResponse.fromJson(Map<String, dynamic> json) =>
      SubmitMiningResponse(
        walletAddress: json['wallet_address'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        matrixUserId: json['matrix_user_id'] as String? ?? '',
        matrixAccessToken: json['matrix_access_token'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
      );
}

class QuickAuthResponse {
  final String matrixUserId;
  final String matrixAccessToken;
  final String deviceId;

  const QuickAuthResponse({
    required this.matrixUserId,
    required this.matrixAccessToken,
    required this.deviceId,
  });

  factory QuickAuthResponse.fromJson(Map<String, dynamic> json) =>
      QuickAuthResponse(
        matrixUserId: json['matrix_user_id'] as String? ?? '',
        matrixAccessToken: json['matrix_access_token'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
      );
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
