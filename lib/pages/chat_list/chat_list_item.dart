import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/presentation/mixins/chat_list_item_mixin.dart';
import 'package:fluffychat/utils/dm_room_contacts_overlay.dart';
import 'package:fluffychat/zeon/widgets/zeon_dialog.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_subtitle.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_title.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/avatar/avatar_style.dart';
import 'package:fluffychat/widgets/avatar/room_avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

import 'package:dartz/dartz.dart' show Either;
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
      final confirmed = await ZeonDialog.confirm(
        context,
        title: L10n.of(context)!.areYouSure,
        okLabel: L10n.of(context)!.yes,
        cancelLabel: L10n.of(context)!.no,
        destructive: true,
        useRootNavigator: false,
      );
      if (!confirmed) return;
      await TwakeDialog.showFutureLoadingDialogFullScreen(
        future: () => room.leave(),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
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
            child: ValueListenableBuilder<Either<Failure, Success>>(
              valueListenable:
                  getIt.get<ContactsManager>().getContactsNotifier(),
              builder: (context, contactsState, _) {
                final resolvedDisplayName =
                    DmRoomContactsOverlay.resolvedDisplayName(
                  room,
                  MatrixLocals(L10n.of(context)!),
                  contactsState,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isEnableSelectMode) checkBoxWidget ?? const SizedBox(),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: ChatListDmAvatar(
                        client: client,
                        room: room,
                        resolvedDisplayName: resolvedDisplayName,
                        size: 60,
                        onTap: onTapAvatar,
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
                            displayNameOverride: resolvedDisplayName,
                          ),
                          const SizedBox(height: 4),
                          ChatListItemSubtitle(
                            room: room,
                            lastEvent: lastEvent,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// DM 会话在 Room 层暂无 [Room.avatar] 时，用 Profile API 补头像（行为对齐通讯录列表）。
class ChatListDmAvatar extends StatefulWidget {
  final Client client;
  final Room room;
  final String resolvedDisplayName;
  final double size;
  final VoidCallback? onTap;

  const ChatListDmAvatar({
    super.key,
    required this.client,
    required this.room,
    required this.resolvedDisplayName,
    this.size = AvatarStyle.defaultSize,
    this.onTap,
  });

  @override
  State<ChatListDmAvatar> createState() => _ChatListDmAvatarState();
}

class _ChatListDmAvatarState extends State<ChatListDmAvatar> {
  Future<Profile?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileIfNeeded();
  }

  @override
  void didUpdateWidget(ChatListDmAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id ||
        oldWidget.room.avatar != widget.room.avatar ||
        oldWidget.room.directChatMatrixID !=
            widget.room.directChatMatrixID) {
      _profileFuture = _loadProfileIfNeeded();
    }
  }

  Future<Profile?>? _loadProfileIfNeeded() {
    final r = widget.room;
    if (!r.isDirectChat) return null;
    final mxid = r.directChatMatrixID;
    if (mxid == null || r.avatar != null) return null;
    return widget.client.getProfileFromUserId(
      mxid,
      getFromRooms: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    if (!r.isDirectChat || r.directChatMatrixID == null || r.avatar != null) {
      return RoomAvatar(
        room: r,
        name: widget.resolvedDisplayName,
        size: widget.size,
        onTap: widget.onTap,
        fontSize: AvatarStyle.defaultFontSize,
        keepAlive: true,
      );
    }

    final fut = _profileFuture;
    if (fut == null) {
      return RoomAvatar(
        room: r,
        name: widget.resolvedDisplayName,
        size: widget.size,
        onTap: widget.onTap,
        fontSize: AvatarStyle.defaultFontSize,
        keepAlive: true,
      );
    }

    return FutureBuilder<Profile?>(
      future: fut,
      builder: (context, snapshot) {
        final uri = r.avatar ?? snapshot.data?.avatarUrl;
        return Avatar(
          mxContent: uri,
          name: widget.resolvedDisplayName,
          size: widget.size,
          onTap: widget.onTap,
          fontSize: AvatarStyle.defaultFontSize,
          keepAlive: true,
        );
      },
    );
  }
}
