import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_title_style.dart';
import 'package:fluffychat/presentation/mixins/chat_list_item_mixin.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_style.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matrix/matrix.dart';

class ChatListItemTitle extends StatelessWidget with ChatListItemMixin {
  final Room room;

  final DateTime? originServerTs;

  const ChatListItemTitle({super.key, required this.room, this.originServerTs});

  @override
  Widget build(BuildContext context) {
    final displayName = room.getLocalizedDisplayname(
      MatrixLocals(L10n.of(context)!),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Padding(
                      padding: ChatListItemTitleStyle.paddingRightTitle,
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  if (room.encrypted)
                    Padding(
                      padding: ChatListItemTitleStyle.paddingLeftIcon,
                      child: SvgPicture.asset(
                        ImagePaths.icEncrypted,
                        width: ChatListItemTitleStyle.encryptedInconWidth,
                        height: ChatListItemTitleStyle.encryptedInconHeight,
                      ),
                    ),
                  if (room.isFavourite)
                    Padding(
                      padding: ChatListItemTitleStyle.paddingLeftIcon,
                      child: Icon(
                        Icons.push_pin_outlined,
                        size: ChatListItemStyle.readIconSize,
                        color: ChatListItemStyle.pinnedIconColor,
                      ),
                    ),
                  if (room.isMuted)
                    Padding(
                      padding: ChatListItemTitleStyle.paddingLeftIcon,
                      child: Icon(
                        Icons.volume_off_outlined,
                        size: ChatListItemStyle.readIconSize,
                        color: ChatListItemStyle.pinnedIconColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: ChatListItemTitleStyle.paddingLeftIcon,
          child: Row(
            children: [
              if (room.isTypingText(context)) ...[
                const Icon(
                  Icons.schedule,
                  color: Color(0xFF919191),
                  size: 16,
                ),
              ],
              Padding(
                padding: ChatListItemTitleStyle.paddingLeftIcon,
                child: Text(
                  (originServerTs ?? room.latestEventReceivedTime)
                      .localizedTimeShort(context),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
