import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:fluffychat/presentation/mixins/chat_list_item_mixin.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_subtitle.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_title.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

enum ArchivedRoomAction { delete, rejoin }

class ChatListItem extends StatelessWidget with ChatListItemMixin {
  final Room room;
  final bool activeChat;
  final bool isSelectedItem;
  final bool isEnableSelectMode;
  final Widget? checkBoxWidget;
  final void Function()? onTap;
  final void Function()? onTapAvatar;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final void Function()? onLongPress;
  final Event? lastEvent;

  const ChatListItem(
    this.room, {
    this.checkBoxWidget,
    this.activeChat = false,
    this.isSelectedItem = false,
    this.isEnableSelectMode = false,
    this.onTap,
    this.onTapAvatar,
    this.onSecondaryTapDown,
    this.onLongPress,
    this.lastEvent,
    super.key,
  });

  void clickAction(BuildContext context) async {
    if (onTap != null) return onTap!();
    switch (room.membership) {
      case Membership.ban:
        TwakeSnackBar.show(
          context,
          L10n.of(context)!.youHaveBeenBannedFromThisChat,
        );
        return;
      case Membership.leave:
        context.go('/archive/${room.id}');
      case Membership.invite:
      case Membership.join:
        context.go('/rooms/${room.id}');
      default:
        return;
    }
  }

  Future<void> archiveAction(BuildContext context) async {
    {
      if ([Membership.leave, Membership.ban].contains(room.membership)) {
        await TwakeDialog.showFutureLoadingDialogFullScreen(
          future: () => room.forget(),
        );
        return;
      }
      final confirmed = await showOkCancelAlertDialog(
        useRootNavigator: false,
        context: context,
        title: L10n.of(context)!.areYouSure,
        okLabel: L10n.of(context)!.yes,
        cancelLabel: L10n.of(context)!.no,
      );
      if (confirmed == OkCancelResult.cancel) return;
      await TwakeDialog.showFutureLoadingDialogFullScreen(
        future: () => room.leave(),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = room.getLocalizedDisplayname(
      MatrixLocals(L10n.of(context)!),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => clickAction(context),
          onSecondaryTapDown: onSecondaryTapDown,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0x1AFFFFFF),
          highlightColor: const Color(0x0DFFFFFF),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: activeChat
                ? BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isEnableSelectMode) checkBoxWidget ?? const SizedBox(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: Avatar(
                    mxContent: room.avatar,
                    name: displayName,
                    size: 60,
                    onTap: onTapAvatar,
                    keepAlive: true,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChatListItemTitle(
                        room: room,
                        originServerTs: lastEvent?.originServerTs,
                      ),
                      const SizedBox(height: 4),
                      ChatListItemSubtitle(room: room, lastEvent: lastEvent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
