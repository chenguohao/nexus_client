import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/isrg_x1.dart';
import 'package:fluffychat/config/isrg_x2.dart';

/// 给 Android 平台用的自定义 HttpClient。
///
/// **背景**：Dart 在 Android 上的 [SecurityContext.defaultContext] 走的不是
/// Android 系统 trust store，而是 dart:io 内置的 BoringSSL + Mozilla NSS
/// PEM bundle。Flutter SDK 不同版本嵌入的 bundle 时间不同，老一些的版本
/// 可能缺 Let's Encrypt 的 ISRG Root X1 / X2 这类相对较新的根证书。
///
/// 当前 Zeon 的生产证书链是：
///   zeon-im.com (leaf) → E7 (LE 中间证书) → ISRG Root X1（cross-signed）
/// 同时 LE 也提供 E1–E9 → ISRG Root X2 的纯 ECDSA 链，未来可能任何时候切过去。
///
/// 所以在 Android 上我们主动把 **X1 和 X2 同时**注入 default context，
/// 保证 TLS 验证不会因为客户端缺根证书而 handshake 失败。
///
/// **iOS / Mac / Windows** 走系统 trust store（NSURLSession 等），由
/// [package:fluffychat/utils/client_manager.dart] 里
/// `PlatformInfos.isAndroid ? CustomHttpClient.createHTTPClient() : null`
/// 显式跳过。
class CustomHttpClient {
  /// 把一组额外信任的 PEM 证书追加进默认 [SecurityContext]，并基于该
  /// context 创建一个 HttpClient。
  ///
  /// 单张证书注入失败**不会**让整个调用抛错——只会用 [Logs] 记一条 warn，
  /// 然后继续注入下一张、继续返回 HttpClient。这样即使将来又新增一张证书
  /// 出现 PEM 解析问题，也不至于直接打挂整个网络层。
  static HttpClient customHttpClient(List<String> extraTrustedPemCerts) {
    final context = SecurityContext.defaultContext;
    for (final pem in extraTrustedPemCerts) {
      _injectTrustedCert(context, pem);
    }
    return HttpClient(context: context);
  }

  /// 给指定 [context] 注入一张 PEM 证书。
  /// - 已存在（`CERT_ALREADY_IN_HASH_TABLE`）→ 静默忽略；
  /// - 其它 TLS 异常 → 记日志但不 rethrow；
  /// - 其它任何异常 → 记日志但不 rethrow。
  static void _injectTrustedCert(SecurityContext context, String pem) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    } on TlsException catch (e) {
      final osMsg = e.osError?.message ?? '';
      if (osMsg.contains('CERT_ALREADY_IN_HASH_TABLE')) {
        return;
      }
      Logs().w(
        'CustomHttpClient: failed to inject trusted cert: '
        'type=${e.type}, message=${e.message}, osError=$osMsg',
      );
    } catch (e) {
      Logs().w('CustomHttpClient: unexpected error injecting trusted cert: $e');
    }
  }

  /// matrix_dart_sdk 和 dio 用的 http.Client 工厂。
  static http.Client createHTTPClient() =>
      IOClient(customHttpClient(const [ISRG_X1, ISRG_X2]));
}
