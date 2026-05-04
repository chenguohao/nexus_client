import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/app_state/user_info/get_user_info_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/contact.dart';
import 'package:fluffychat/domain/model/extensions/contact/contact_extension.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:fluffychat/utils/clipboard.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' hide Contact;

/// "Sovereign Architect" 风格的联系人详情信息卡。
///
/// 包含：
/// - Email / Phone 行（如有）
/// - Web only：Add to contacts 行
/// - 1对1 房间：Leave chat 行
/// - Block / Unblock 行
///
/// 注意：Message 按钮、Search 按钮、Zeon ID 行 已上移到顶部头组件，
/// 这里不再重复展示。
class ChatProfileInfoDetails extends StatelessWidget {
  static const Key leaveChatButtonKey = Key('leave_chat_button');

  const ChatProfileInfoDetails({
    super.key,
    this.displayName,
    this.matrixId,
    required this.userInfoNotifier,
    required this.isBlockedUserNotifier,
    this.onUnblockUser,
    this.onBlockUser,
    required this.blockUserLoadingNotifier,
    required this.isAlreadyInChat,
    this.room,
    this.onLeaveChat,
  });

  final String? displayName;
  final String? matrixId;
  final ValueNotifier<Either<Failure, Success>> userInfoNotifier;
  final ValueNotifier<bool> isBlockedUserNotifier;
  final void Function()? onUnblockUser;
  final void Function()? onBlockUser;
  final ValueNotifier<bool?> blockUserLoadingNotifier;
  final bool isAlreadyInChat;
  final Room? room;
  final void Function()? onLeaveChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: ZeonColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: userInfoNotifier,
              builder: (context, value, _) {
                return value.fold(
                  (failure) => const SizedBox.shrink(),
                  (success) {
                    if (success is GetUserInfoSuccess) {
                      final emails = success.userInfo.emails;
                      final phones = success.userInfo.phones;
                      return Column(
                        children: [
                          if (emails?.firstOrNull != null)
                            _ZeonInfoRow(
                              icon: Icons.alternate_email,
                              title: L10n.of(context)!.email,
                              text: emails!.first,
                            ),
                          if (phones?.firstOrNull != null)
                            _ZeonInfoRow(
                              icon: Icons.call_outlined,
                              title: L10n.of(context)!.phoneNumber,
                              text: phones!.first,
                            ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: getIt
                  .get<ContactsManager>()
                  .getContactsNotifier(),
              builder: (context, state, _) {
                if (!_canAddContact(state)) return const SizedBox.shrink();
                return _ZeonActionRow(
                  icon: Icons.person_add_outlined,
                  text: L10n.of(context)!.addToContacts,
                  onTap: () => showAddContactDialog(
                    context,
                    matrixId: matrixId,
                    displayName: displayName,
                  ),
                );
              },
            ),
            if (room?.isDirectChat == true)
              _ZeonActionRow(
                key: leaveChatButtonKey,
                icon: Icons.logout_outlined,
                text: L10n.of(context)!.leaveChat,
                onTap: onLeaveChat,
              ),
            ValueListenableBuilder(
              valueListenable: blockUserLoadingNotifier,
              builder: (context, isLoading, _) {
                return ValueListenableBuilder(
                  valueListenable: isBlockedUserNotifier,
                  builder: (context, isBlockedUser, _) {
                    return _ZeonActionRow(
                      icon: Icons.front_hand_outlined,
                      text: isBlockedUser
                          ? L10n.of(context)!.unblockUser
                          : L10n.of(context)!.blockUser,
                      // Block 是危险动作 → 用 error 红
                      color: ZeonColors.error,
                      trailing: isLoading == true
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: CupertinoActivityIndicator(
                                animating: true,
                                color: ZeonColors.onSurfaceVariant,
                              ),
                            )
                          : null,
                      onTap: isLoading == true
                          ? null
                          : isBlockedUser
                          ? onUnblockUser
                          : onBlockUser,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canAddContact(Either<Failure, Success> state) {
    if (PlatformInfos.isMobile || matrixId == null) return false;

    final List<Contact> contacts = state.fold(
      (failure) => [],
      (success) => success is GetContactsSuccess ? success.contacts : [],
    );
    return contacts.none((contact) => contact.inTomAddressBook(matrixId!));
  }
}

class _ZeonInfoRow extends StatelessWidget {
  const _ZeonInfoRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          TwakeClipboard.instance.copyText(text);
          TwakeSnackBar.show(context, L10n.of(context)!.copiedToClipboard);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ZeonColors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: ZeonColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: const TextStyle(
                        color: ZeonColors.onSurface,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.copy,
                size: 16,
                color: ZeonColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZeonActionRow extends StatelessWidget {
  const _ZeonActionRow({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? ZeonColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
