import 'dart:convert';

import 'package:fluffychat/config/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

mixin WellKnownMixin {
  static const twakeChatKey = 'app.twake.chat';
  static const _enableInvitation = 'enable_invitations';
  static const supportContact = 'support_contact';

  final ValueNotifier<DiscoveryInformation?> discoveryInformationNotifier =
      ValueNotifier(null);

  /// Fetches /.well-known/matrix/client directly from the Nexus server instead
  /// of letting the Matrix SDK auto-derive the URL from the user ID's domain.
  /// The SDK approach tries https://<serverName>/.well-known/matrix/client which
  /// fails in local-dev (Android emulator) because "localhost" resolves to the
  /// emulator itself, not the host machine running the server.
  Future<void> getWellKnownInformation(Client client) async {
    try {
      final uri = Uri.parse(
        '${AppConstants.nexusServerUrl}/.well-known/matrix/client',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('well-known returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, Object?>;
      final result = DiscoveryInformation.fromJson(json);
      Logs().d('WellKnownMixin::getWellKnownInformation() well-known $result');
      discoveryInformationNotifier.value = result;
    } catch (e) {
      discoveryInformationNotifier.value = null;
      Logs().e(
        'WellKnownMixin::getWellKnownInformation() Error checking wellknown status: $e',
      );
    }
  }

  bool supportInvitation() {
    final additionalProperties =
        discoveryInformationNotifier.value?.additionalProperties;
    final twakeChatData = additionalProperties?[twakeChatKey];
    final enableInvitation = twakeChatData is Map<String, dynamic>
        ? twakeChatData[_enableInvitation] as bool?
        : null;
    Logs().d(
      'WellKnownMixin::supportInvitation(): enableInvitation - $enableInvitation',
    );
    return enableInvitation ?? false;
  }
}
