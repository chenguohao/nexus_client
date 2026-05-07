import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

class ApiService {
  // 编译时从配置文件注入（config/debug.json 或 config/release.json）。
  //
  // Debug:   ZEON_SERVER_URL=http://192.168.31.212:8080  （局域网直连，裸 HTTP）
  // Release: ZEON_SERVER_URL=https://zeon-im.com         （生产域名，不带端口）
  //
  // 注意：生产环境不能带 :8080 端口，因为 8080 跑的是裸 HTTP，
  // 必须经过 Nginx 反向代理在 443 端口统一终止 TLS 后再内部转发。
  static const envServerUrl = String.fromEnvironment('ZEON_SERVER_URL');

  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? envServerUrl;

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

  /// Resolves a wallet address to its 6-char Zeon UID, which is also the
  /// Matrix localpart. Used by the key-card recovery flow before /quick-login.
  Future<String> lookupUid({required String walletAddress}) async {
    final uri = Uri.parse('$baseUrl/lookup-uid');
    final body = jsonEncode({'wallet_address': walletAddress});
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));
    _assertOk(response, 'lookup-uid');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final uid = json['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      throw const ApiException('[lookup-uid] empty uid in response');
    }
    return uid;
  }

  void _assertOk(http.Response response, String endpoint) {
    if (response.statusCode != 200) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        message = json['error'] as String? ?? message;
      } catch (_) {}
      developer.log(
        'status=${response.statusCode} body=${response.body}',
        name: 'ZeonApi.$endpoint',
      );
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
