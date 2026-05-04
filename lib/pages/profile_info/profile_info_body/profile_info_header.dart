import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/domain/app_state/user_info/get_user_info_state.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/presence_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/zeon/zeon_profile_header.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Header section of a contact's profile (Contact info page).
///
/// Renders the shared [ZeonProfileHeader] so that this surface stays visually
/// consistent with the user's own profile page (`ZeonProfilePage`) and the
/// chat-side contact panel (`ChatProfileInfoAppBar`). The current presence
/// text — when available — is passed through as the header's `subtitle`.
///
/// `animationController` and `onAvatarInfoTap` are kept on the public API for
/// backwards compatibility with the existing `ProfileInfoBodyView` call site;
/// the animation is no longer consumed here because the editorial layout does
/// not collapse, and tapping the avatar simply forwards to the legacy callback.
class ProfileInfoHeader extends StatelessWidget {
  const ProfileInfoHeader({
    required this.user,
    required this.userInfoNotifier,
    required this.animationController,
    required this.onAvatarInfoTap,
    super.key,
  });

  final User user;
  final ValueNotifier<Either<Failure, Success>> userInfoNotifier;
  final AnimationController animationController;
  final VoidCallback onAvatarInfoTap;

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final presence = client.presences[user.id];

    return ValueListenableBuilder(
      valueListenable: userInfoNotifier,
      builder: (context, userInfo, _) {
        final userInfoModel = userInfo
            .getSuccessOrNull<GetUserInfoSuccess>()
            ?.userInfo;
        final displayName =
            userInfoModel?.displayName ?? user.calcDisplayname();

        // Prefer the latest avatar from the user-info call; fall back to the
        // avatar embedded in the User object (which Matrix sync gives us).
        final remoteAvatar = userInfoModel?.avatarUrl;
        final avatarUri = (remoteAvatar != null && remoteAvatar.isNotEmpty)
            ? Uri.tryParse(remoteAvatar)
            : user.avatarUrl;

        Widget? subtitle;
        if (presence != null) {
          subtitle = Text(
            presence.getLocalizedStatusMessage(context),
            style: const TextStyle(
              color: ZeonColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          );
        }

        return ZeonProfileHeader(
          avatarUri: avatarUri,
          displayName: displayName,
          mxid: user.id,
          subtitle: subtitle,
          onTapAvatar: onAvatarInfoTap,
        );
      },
    );
  }
}
