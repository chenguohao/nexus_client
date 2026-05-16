import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/pages/chat_details/chat_details_page_view/chat_details_page_enum.dart';
import 'package:fluffychat/pages/chat_profile_info/chat_profile_info_details.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/zeon/zeon_profile_header.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

/// "Sovereign Architect" 风格的联系人详情头部 sliver 集合。
///
/// 自上而下：
/// 1. [ZeonProfileHeader] — 头像 + 昵称 + Zeon ID（与个人页共享）
/// 2. 主操作按钮 Message
/// 3. [ChatProfileInfoDetails] — 信息卡（email/phone/block/leave）
/// 4. 固定吸顶的 [TabBar]（共享媒体/链接/文件）
class ChatProfileInfoAppBar extends StatefulWidget {
  final ValueNotifier<Either<Failure, Success>> userInfoNotifier;
  final Room? room;
  final User? user;
  final PresentationContact? presentationContact;
  final bool isAlreadyInChat;
  final List<ChatDetailsPage> tabList;
  final TabController? tabController;
  final Uri? avatarUri;
  final String? displayName;
  final String? matrixId;
  final ValueNotifier<bool> isBlockedUserNotifier;
  final void Function()? onUnblockUser;
  final void Function()? onBlockUser;
  final ValueNotifier<bool?> blockUserLoadingNotifier;
  final void Function(BuildContext context, Room? room)? onLeaveChat;
  final bool innerBoxIsScrolled;
  final VoidCallback onMessage;

  const ChatProfileInfoAppBar({
    super.key,
    required this.userInfoNotifier,
    this.room,
    this.user,
    this.presentationContact,
    required this.tabList,
    this.tabController,
    required this.isAlreadyInChat,
    this.avatarUri,
    this.displayName,
    this.matrixId,
    required this.isBlockedUserNotifier,
    this.onUnblockUser,
    this.onBlockUser,
    required this.blockUserLoadingNotifier,
    this.onLeaveChat,
    required this.innerBoxIsScrolled,
    required this.onMessage,
  });

  /// 直接返回多个 sliver，调用方将其展开放入 [NestedScrollView.headerSliverBuilder]。
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: _ChatProfileInfoHeader(
          userInfoNotifier: userInfoNotifier,
          room: room,
          presentationContact: presentationContact,
          isAlreadyInChat: isAlreadyInChat,
          avatarUri: avatarUri,
          displayName: displayName,
          matrixId: matrixId,
          isBlockedUserNotifier: isBlockedUserNotifier,
          onUnblockUser: onUnblockUser,
          onBlockUser: onBlockUser,
          blockUserLoadingNotifier: blockUserLoadingNotifier,
          onLeaveChat: onLeaveChat,
          onMessage: onMessage,
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: _ZeonTabBarDelegate(
          tabList: tabList,
          tabController: tabController,
        ),
      ),
    ];
  }

  @override
  State<ChatProfileInfoAppBar> createState() => _ChatProfileInfoAppBarState();
}

/// Backwards-compat fallback widget — most callers use [buildSlivers] directly,
/// but if anything still embeds this widget (e.g. unit tests), render the
/// header as a plain box so it doesn't crash.
class _ChatProfileInfoAppBarState extends State<ChatProfileInfoAppBar> {
  @override
  Widget build(BuildContext context) {
    return _ChatProfileInfoHeader(
      userInfoNotifier: widget.userInfoNotifier,
      room: widget.room,
      presentationContact: widget.presentationContact,
      isAlreadyInChat: widget.isAlreadyInChat,
      avatarUri: widget.avatarUri,
      displayName: widget.displayName,
      matrixId: widget.matrixId,
      isBlockedUserNotifier: widget.isBlockedUserNotifier,
      onUnblockUser: widget.onUnblockUser,
      onBlockUser: widget.onBlockUser,
      blockUserLoadingNotifier: widget.blockUserLoadingNotifier,
      onLeaveChat: widget.onLeaveChat,
      onMessage: widget.onMessage,
    );
  }
}

class _ChatProfileInfoHeader extends StatefulWidget {
  const _ChatProfileInfoHeader({
    required this.userInfoNotifier,
    this.room,
    this.presentationContact,
    required this.isAlreadyInChat,
    this.avatarUri,
    this.displayName,
    this.matrixId,
    required this.isBlockedUserNotifier,
    this.onUnblockUser,
    this.onBlockUser,
    required this.blockUserLoadingNotifier,
    this.onLeaveChat,
    required this.onMessage,
  });

  final ValueNotifier<Either<Failure, Success>> userInfoNotifier;
  final Room? room;
  final PresentationContact? presentationContact;
  final bool isAlreadyInChat;
  final Uri? avatarUri;
  final String? displayName;
  final String? matrixId;
  final ValueNotifier<bool> isBlockedUserNotifier;
  final void Function()? onUnblockUser;
  final void Function()? onBlockUser;
  final ValueNotifier<bool?> blockUserLoadingNotifier;
  final void Function(BuildContext context, Room? room)? onLeaveChat;
  final VoidCallback onMessage;

  @override
  State<_ChatProfileInfoHeader> createState() => _ChatProfileInfoHeaderState();
}

class _ChatProfileInfoHeaderState extends State<_ChatProfileInfoHeader> {
  final ValueNotifier<Profile?> _profileNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _loadProfileIfNeeded();
  }

  @override
  void didUpdateWidget(_ChatProfileInfoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentationContact?.matrixId !=
        widget.presentationContact?.matrixId) {
      _loadProfileIfNeeded();
    }
  }

  Future<void> _loadProfileIfNeeded() async {
    if (!mounted) return;
    final matrixId = widget.presentationContact?.matrixId;
    if (matrixId != null) {
      try {
        final profile = await Matrix.of(
          context,
        ).client.getProfileFromUserId(matrixId, getFromRooms: false);
        if (!mounted) return;
        _profileNotifier.value = profile;
      } catch (_) {
        if (!mounted) return;
        _profileNotifier.value = null;
      }
    } else {
      _profileNotifier.value = null;
    }
  }

  @override
  void dispose() {
    _profileNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Profile?>(
      valueListenable: _profileNotifier,
      builder: (context, profile, _) {
        final contact = widget.presentationContact;
        final resolvedAvatar = profile?.avatarUrl ?? widget.avatarUri;
        final resolvedDisplayName =
            profile?.displayName ??
            contact?.displayName ??
            widget.displayName ??
            '';
        final resolvedMxid = contact?.matrixId ?? widget.matrixId;
        final matrixClient =
            widget.room?.client ?? Matrix.of(context).client;
        final rm = resolvedMxid;
        final privacyMaskStranger = rm != null &&
            !getIt.get<ContactsManager>().isAcceptedFriend(rm);

        return Container(
          color: ZeonColors.background,
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZeonProfileHeader(
                avatarUri: resolvedAvatar,
                displayName: resolvedDisplayName,
                mxid: resolvedMxid,
                matrixClient: matrixClient,
                privacyMaskStranger: privacyMaskStranger,
              ),
              const SizedBox(height: 4),
              _MessagePrimaryAction(onTap: widget.onMessage),
              const SizedBox(height: 16),
              ChatProfileInfoDetails(
                displayName: resolvedDisplayName,
                matrixId: resolvedMxid,
                userInfoNotifier: widget.userInfoNotifier,
                isAlreadyInChat: widget.isAlreadyInChat,
                isBlockedUserNotifier: widget.isBlockedUserNotifier,
                onUnblockUser: widget.onUnblockUser,
                onBlockUser: widget.onBlockUser,
                blockUserLoadingNotifier: widget.blockUserLoadingNotifier,
                room: widget.room,
                onLeaveChat: () =>
                    widget.onLeaveChat?.call(context, widget.room),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessagePrimaryAction extends StatelessWidget {
  const _MessagePrimaryAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Material(
          color: ZeonColors.primary,
          borderRadius: BorderRadius.circular(2),
          child: InkWell(
            borderRadius: BorderRadius.circular(2),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: ZeonColors.onPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    L10n.of(context)!.message.toUpperCase(),
                    style: const TextStyle(
                      color: ZeonColors.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZeonTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ZeonTabBarDelegate({required this.tabList, required this.tabController});

  final List<ChatDetailsPage> tabList;
  final TabController? tabController;

  static const double _height = 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _height,
      color: ZeonColors.background,
      child: TabBar(
        physics: const NeverScrollableScrollPhysics(),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: ZeonColors.primary,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
        indicatorWeight: 2,
        dividerColor: ZeonColors.outlineVariant.withValues(alpha: 0.3),
        labelColor: ZeonColors.primary,
        unselectedLabelColor: ZeonColors.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
        tabs: tabList.map((page) {
          return Tab(
            child: Text(
              page.getTitle(context).toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
            ),
          );
        }).toList(),
        controller: tabController,
      ),
    );
  }

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  bool shouldRebuild(_ZeonTabBarDelegate oldDelegate) {
    return oldDelegate.tabList != tabList ||
        oldDelegate.tabController != tabController;
  }
}
