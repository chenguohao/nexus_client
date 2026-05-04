import 'package:fluffychat/pages/profile_info/profile_info_body/profile_info_body.dart';
import 'package:fluffychat/pages/profile_info/profile_info_body/profile_info_body_view_style.dart';
import 'package:fluffychat/pages/profile_info/profile_info_body/profile_info_contact_rows.dart';
import 'package:fluffychat/pages/profile_info/profile_info_body/profile_info_header.dart';
import 'package:flutter/material.dart';

class ProfileInfoBodyView extends StatelessWidget {
  const ProfileInfoBodyView({required this.controller, super.key});

  final ProfileInfoBodyController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // The Sovereign-style identity header is fully self-contained (it draws
    // its own avatar tile and abstract placeholder), so we no longer need the
    // legacy blurred avatar backdrop / gradient overlay that the old design
    // layered behind the name. Just stack the shared header above the rest.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileInfoHeader(
          user: controller.user!,
          userInfoNotifier: controller.userInfoNotifier,
          animationController: controller.animationController,
          onAvatarInfoTap: controller.onAvatarInfoTap,
        ),
        const SizedBox(height: 24),
        ProfileInfoContactRows(
          user: controller.user!,
          userInfoNotifier: controller.userInfoNotifier,
        ),
        if (!controller.isOwnProfile) ...[
          Padding(
            padding: ProfileInfoBodyViewStyle.actionsPadding,
            child: controller.buildProfileInfoActions(context),
          ),
        ] else
          const SizedBox(height: 16),
      ],
    );
  }
}
