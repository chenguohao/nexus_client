import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat_details/chat_details_group_actions_view.dart';
import 'package:fluffychat/pages/chat_details/chat_details_group_info_background_view.dart';
import 'package:fluffychat/pages/chat_details/chat_details_group_information_view.dart';
import 'package:fluffychat/pages/chat_details/chat_details_view_style.dart';
import 'package:fluffychat/presentation/extensions/room_summary_extension.dart';
import 'package:fluffychat/widgets/avatar/room_avatar.dart';
import 'package:fluffychat/widgets/avatar/secondary_avatar.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatDetailsHeaderStack extends StatelessWidget {
  const ChatDetailsHeaderStack({
    super.key,
    required this.room,
    required this.animationController,
    required this.groupInfoHeight,
    required this.maxGroupInfoHeight,
    required this.onMessage,
    required this.onSearch,
    required this.onToggleNotification,
    required this.muteNotifier,
    required this.onGroupInfoTap,
  });

  final Room room;
  final AnimationController animationController;
  final double groupInfoHeight;
  final double maxGroupInfoHeight;
  final VoidCallback onMessage;
  final VoidCallback onSearch;
  final VoidCallback onToggleNotification;
  final ValueNotifier<PushRuleState> muteNotifier;
  final VoidCallback onGroupInfoTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _ChatDetailsBackdropAvatar(
            room: room,
            animationController: animationController,
          ),
        ),
        Positioned.fill(
          child: ChatDetailsGroupInfoBackgroundView(
            animationController: animationController,
          ),
        ),
        Column(
          children: [
            ChatDetailsGroupInformationView(
              height: groupInfoHeight,
              maxHeight: maxGroupInfoHeight,
              animationController: animationController,
              displayName: room.getLocalizedDisplayname(),
              subTitle: room.summary.actualMembersCount > 0
                  ? L10n.of(
                      context,
                    )?.countMembers(room.summary.actualMembersCount)
                  : '',
              onTap: onGroupInfoTap,
            ),
            ChatDetailsGroupActionsView(
              onMessage: onMessage,
              onSearch: onSearch,
              onToggleNotification: onToggleNotification,
              muteNotifier: muteNotifier,
              animationController: animationController,
            ),
          ],
        ),
      ],
    );
  }
}

/// 与聊天列表一致：群聊未设置 [Room.avatar] 时用成员拼图；否则沿用大图单帧逻辑。
class _ChatDetailsBackdropAvatar extends StatelessWidget {
  const _ChatDetailsBackdropAvatar({
    required this.room,
    required this.animationController,
  });

  final Room room;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    final useCompositeGroupAvatar =
        !room.isDirectChat && room.avatar == null;

    if (!useCompositeGroupAvatar) {
      return SecondaryAvatar(
        animationController: animationController,
        mxContent: room.avatar,
        name: room.getLocalizedDisplayname(),
        fontSize: ChatDetailViewStyle.avatarFontSize,
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final size = Tween<double>(
      begin: ChatDetailViewStyle.avatarSize,
      end: screenWidth,
    ).transform(animationController.value);
    final paddingTop = Tween<double>(
      begin: 16,
      end: 0,
    ).transform(animationController.value);

    return Container(
      padding: EdgeInsets.only(top: paddingTop),
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: IgnorePointer(
          child: RoomAvatar(
            room: room,
            name: room.getLocalizedDisplayname(),
            size: size,
            fontSize: ChatDetailViewStyle.avatarFontSize,
            keepAlive: true,
          ),
        ),
      ),
    );
  }
}
