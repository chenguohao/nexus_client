import 'package:dio/dio.dart';
import 'package:fluffychat/data/model/addressbook/address_book.dart';
import 'package:fluffychat/data/network/dio_client.dart';
import 'package:fluffychat/data/network/tom_endpoint.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/di/global/network_di.dart';

/// 服务端报错的解析结果。
class FriendRequestApiException implements Exception {
  /// duplicate / already_friend / not_pending / not_owner / not_found / other
  final String code;
  final String message;
  final int statusCode;

  FriendRequestApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => 'FriendRequestApiException($code, $statusCode): $message';
}

/// 好友请求生命周期相关的 HTTP 调用：
///   POST  /_twake/addressbook/request
///   POST  /_twake/addressbook/accept/:id
///   POST  /_twake/addressbook/reject/:id
class FriendRequestApi {
  final DioClient _client = getIt.get<DioClient>(
    instanceName: NetworkDI.tomDioClientName,
  );

  String get _basePath => TomEndpoint.addressbookServicePath.path;

  /// A 端发起好友请求。返回 A 端这条 contact（status=pending_outgoing）。
  Future<AddressBook> requestFriend({
    required String mxid,
    String? displayName,
    String? roomId,
  }) async {
    try {
      final body = await _client.postToGetBody(
        '$_basePath/request',
        data: {
          'mxid': mxid,
          if (displayName != null) 'display_name': displayName,
          if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
        },
      );
      return AddressBook.fromJson(Map<String, dynamic>.from(body as Map));
    } on DioException catch (e) {
      throw _toFriendRequestException(e);
    }
  }

  /// B 端接受好友请求。
  Future<void> acceptFriend(String contactId) async {
    try {
      await _client.post('$_basePath/accept/$contactId');
    } on DioException catch (e) {
      throw _toFriendRequestException(e);
    }
  }

  /// B 端拒绝好友请求。
  Future<void> rejectFriend(String contactId) async {
    try {
      await _client.post('$_basePath/reject/$contactId');
    } on DioException catch (e) {
      throw _toFriendRequestException(e);
    }
  }

  FriendRequestApiException _toFriendRequestException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    String code = 'other';
    String message = e.message ?? 'request failed';
    final data = e.response?.data;
    if (data is Map) {
      if (data['code'] is String) code = data['code'] as String;
      if (data['error'] is String) message = data['error'] as String;
    }
    return FriendRequestApiException(
      code: code,
      message: message,
      statusCode: status,
    );
  }
}
