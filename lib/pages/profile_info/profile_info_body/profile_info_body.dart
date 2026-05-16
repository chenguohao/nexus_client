import 'dart:async';

import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/default_power_level_member.dart';
import 'package:fluffychat/data/network/contact/friend_request_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/room/set_permission_level_state.dart';
import 'package:fluffychat/domain/app_state/user_info/get_user_info_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/domain/usecase/contacts/request_friend_interactor.dart';
import 'package:fluffychat/domain/usecase/room/set_permission_level_interactor.dart';
import 'package:fluffychat/domain/usecase/user_info/get_user_info_interactor.dart';
import 'package:fluffychat/pages/profile_info/profile_info_body/profile_info_body_view.dart';
import 'package:fluffychat/presentation/enum/profile_info/profile_info_body_enum.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_constant.dart';
import 'package:fluffychat/presentation/model/search/presentation_search.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/dialog/warning_dialog.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/utils/user_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class ProfileInfoBody extends StatefulWidget {
  const ProfileInfoBody({
    required this.user,
    this.onNewChatOpen,
    this.onUpdatedMembers,
    this.onTransferOwnershipSuccess,
    super.key,
  });

  final User? user;

  final VoidCallback? onNewChatOpen;

  final VoidCallback? onUpdatedMembers;

  final VoidCallback? onTransferOwnershipSuccess;

  @override
  State<ProfileInfoBody> createState() => ProfileInfoBodyController();
}

class ProfileInfoBodyController extends State<ProfileInfoBody>
    with SingleTickerProviderStateMixin {
  final _getUserInfoInteractor = getIt.get<GetUserInfoInteractor>();

  final _setPermissionLevelInteractor = getIt
      .get<SetPermissionLevelInteractor>();

  final responsive = getIt.get<ResponsiveUtils>();

  StreamSubscription? _setPermissionLevelSubscription;

  StreamSubscription? userInfoNotifierSub;

  final ValueNotifier<Either<Failure, Success>> userInfoNotifier =
      ValueNotifier<Either<Failure, Success>>(Right(GettingUserInfo()));

  late AnimationController animationController;

  final ValueNotifier<bool> isExpandedAvatar = ValueNotifier<bool>(false);

  Timer? _avatarToggleTimer;

  static const int _animationDuration = 100;

  User? get user => widget.user;

  bool get isOwnProfile => user?.id == user?.room.client.userID;

  void getUserInfoAction() {
    if (user == null) return;
    userInfoNotifierSub = _getUserInfoInteractor
        .execute(userId: user!.id)
        .listen((event) => userInfoNotifier.value = event);
  }

  void openNewChat() {
    if (user == null) return;
    final roomId = Matrix.of(context).client.getDirectChatFromUserId(user!.id);

    if (roomId == null) {
      if (!PlatformInfos.isMobile && widget.onNewChatOpen != null) {
        widget.onNewChatOpen!();
      }

      _goToDraftChat(
        context: context,
        path: "rooms",
        contactPresentationSearch: user!.toContactPresentationSearch(),
      );
    } else {
      if (PlatformInfos.isMobile) {
        Navigator.of(
          context,
        ).popUntil((route) => route.settings.name == "/rooms/room");
      } else {
        if (widget.onNewChatOpen != null) widget.onNewChatOpen!();
      }

      context.go('/rooms/$roomId');
    }
  }

  void _goToDraftChat({
    required BuildContext context,
    required String path,
    required ContactPresentationSearch contactPresentationSearch,
  }) {
    if (contactPresentationSearch.matrixId !=
        Matrix.of(context).client.userID) {
      Router.neglect(
        context,
        () => context.go(
          '/$path/draftChat',
          extra: {
            PresentationContactConstant.receiverId:
                contactPresentationSearch.matrixId ?? '',
            PresentationContactConstant.displayName:
                contactPresentationSearch.displayName ?? '',
            PresentationContactConstant.status: '',
          },
        ),
      );
    }
  }

  Future<void> removeFromGroupChat() async {
    if (user == null) return;
    WarningDialog.hideWarningDialog(context);
    final result = await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () => user!.ban(),
    );
    if (result.error != null) {
      TwakeSnackBar.show(context, result.error!.message);
      return;
    }
    widget.onUpdatedMembers?.call();
  }

  List<ProfileInfoActions> profileInfoActions() {
    return [
      ProfileInfoActions.sendMessage,
      if (user?.canKick == true) ProfileInfoActions.removeFromGroup,
      if (user?.room.canTransferOwnership == true && user?.isBanned == false)
        ProfileInfoActions.transferOwnership,
    ];
  }

  void handleActions(ProfileInfoActions action) {
    switch (action) {
      case ProfileInfoActions.sendMessage:
        _handleSendMessageAction();
        break;
      case ProfileInfoActions.removeFromGroup:
        removeFromGroupChat();
        break;
      case ProfileInfoActions.transferOwnership:
        transferOwnership();
        break;
      default:
        break;
    }
  }

  /// 根据当前用户与对方的好友关系决定 sendMessage 按钮的形态：
  ///   - accepted     → "发消息" + 普通消息图标 + openNewChat
  ///   - pending_out  → "待确认"   + 禁用图标 + 不可点
  ///   - pending_in   → "接受好友请求" + 跳到 DM 邀请房间
  ///   - rejected/无  → "添加好友" + 发起 RequestFriend
  ///   - 自己的资料    → 仍然是"发消息"（照原逻辑）
  ({String label, IconData icon, bool enabled}) _sendMessageButtonState() {
    final mxid = user?.id;
    if (mxid == null || isOwnProfile) {
      return (
        label: L10n.of(context)!.sendMessage,
        icon: Icons.chat_bubble_outline,
        enabled: true,
      );
    }
    final status = getIt.get<ContactsManager>().friendStatusOf(mxid);
    switch (status) {
      case FriendStatus.accepted:
        return (
          label: L10n.of(context)!.sendMessage,
          icon: Icons.chat_bubble_outline,
          enabled: true,
        );
      case FriendStatus.pendingOutgoing:
        return (
          label: '待确认',
          icon: Icons.hourglass_empty,
          enabled: false,
        );
      case FriendStatus.pendingIncoming:
        return (
          label: '接受好友请求',
          icon: Icons.person_add_alt_1,
          enabled: true,
        );
      case FriendStatus.rejected:
      case null:
        return (
          label: '添加好友',
          icon: Icons.person_add_alt_1,
          enabled: true,
        );
    }
  }

  Future<void> _handleSendMessageAction() async {
    final mxid = user?.id;
    if (mxid == null || isOwnProfile) {
      openNewChat();
      return;
    }
    final status = getIt.get<ContactsManager>().friendStatusOf(mxid);
    switch (status) {
      case FriendStatus.accepted:
        openNewChat();
        return;
      case FriendStatus.pendingOutgoing:
        return; // disabled
      case FriendStatus.pendingIncoming:
        // 直接打开 DM 房间，让 chat_invitation_body 接管 accept/reject 流程
        final roomId = Matrix.of(context).client.getDirectChatFromUserId(mxid);
        if (roomId != null) context.go('/rooms/$roomId');
        return;
      case FriendStatus.rejected:
      case null:
        await _sendFriendRequest(mxid);
        return;
    }
  }

  Future<void> _sendFriendRequest(String mxid) async {
    final client = Matrix.of(context).client;
    final res = await TwakeDialog.showFutureLoadingDialogFullScreen<
      ({bool ok, String? error})
    >(
      future: () async {
        try {
          await getIt.get<RequestFriendInteractor>().execute(
            matrixClient: client,
            mxid: mxid,
            displayName: user?.displayName,
          );
          return (ok: true, error: null);
        } on FriendRequestApiException catch (e) {
          return (ok: false, error: e.message);
        } catch (e) {
          return (ok: false, error: e.toString());
        }
      },
    );
    if (!mounted) return;
    final outcome = res.result;
    if (outcome == null || !outcome.ok) {
      TwakeSnackBar.show(
        context,
        outcome?.error ?? 'Failed to send friend request',
      );
      return;
    }
    getIt.get<ContactsManager>().refreshTomContacts(client);
    TwakeSnackBar.show(context, '好友请求已发送，等待对方确认');
    setState(() {});
  }

  Widget buildProfileInfoActions(BuildContext context) {
    final actions = profileInfoActions();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1F474747)),
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFF1C1B1C),
      ),
      child: Column(
        children: List.generate(actions.length, (i) {
          final action = actions[i];
          final isLast = i == actions.length - 1;

          // sendMessage 行根据好友关系状态动态渲染（label/icon/enabled）
          final isSendMessage = action == ProfileInfoActions.sendMessage;
          final sendState = isSendMessage ? _sendMessageButtonState() : null;
          final disabled = sendState != null && !sendState.enabled;

          return Column(
            children: [
              InkWell(
                highlightColor: const Color(0x0DE5E2E3),
                splashColor: const Color(0x1AE5E2E3),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: disabled ? null : () => handleActions(action),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      if (sendState != null) ...[
                        Icon(
                          sendState.icon,
                          size: 18,
                          color: disabled
                              ? const Color(0xFF636363)
                              : const Color(0xFFE5E2E3),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          sendState.label,
                          style: TextStyle(
                            color: disabled
                                ? const Color(0xFF636363)
                                : const Color(0xFFE5E2E3),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        if (action.icon() != null) ...[
                          action.icon()!,
                          const SizedBox(width: 12),
                        ],
                        Text(
                          action.label(context),
                          style: action.textStyle(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  color: Color(0x1F474747),
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> transferOwnership() async {
    if (user == null) return;
    if (user?.room == null) return;
    await showConfirmAlertDialog(
      context: context,
      title: L10n.of(
        context,
      )?.confirmTransferOwnership(user?.displayName ?? ''),
      message: L10n.of(context)?.transferOwnershipDescription,
      okLabel: L10n.of(context)?.confirm,
      cancelLabel: L10n.of(context)?.cancel,
    ).then((result) {
      if (result == ConfirmResult.ok) {
        _setPermissionLevelSubscription = _setPermissionLevelInteractor
            .execute(
              room: user!.room,
              userPermissionLevels: {
                user!: DefaultPowerLevelMember.owner.powerLevel,
                user!.room.ownUser: DefaultPowerLevelMember.admin.powerLevel,
              },
            )
            .listen((state) => _handleSetPermissionState(state));
      }
    });
  }

  void _handleSetPermissionState(Either<Failure, Success> state) {
    state.fold(
      (failure) {
        if (failure is SetPermissionLevelFailure) {
          TwakeDialog.hideLoadingDialog(context);
          TwakeSnackBar.show(context, failure.exception.toString());
          return;
        }

        if (failure is NoPermissionFailure) {
          TwakeDialog.hideLoadingDialog(context);
          TwakeSnackBar.show(
            context,
            L10n.of(context)!.permissionErrorChangeRole,
          );
          return;
        }
      },
      (success) {
        if (success is SetPermissionLevelLoading) {
          TwakeDialog.showLoadingDialog(context);
          return;
        }

        if (success is SetPermissionLevelSuccess) {
          TwakeDialog.hideLoadingDialog(context);
          widget.onTransferOwnershipSuccess?.call();
          return;
        }
      },
    );
  }

  void onAvatarInfoTap() {
    if (!responsive.isMobile(context)) {
      return;
    }
    // Prevent rapid tapping during animation
    if (animationController.isAnimating ||
        (_avatarToggleTimer?.isActive ?? false)) {
      return;
    }
    if (animationController.isCompleted) {
      animationController.reverse();
      _avatarToggleTimer = Timer(
        const Duration(milliseconds: _animationDuration),
        () {
          if (mounted) {
            isExpandedAvatar.value = false;
          }
        },
      );
    } else {
      if (mounted) {
        isExpandedAvatar.value = true;
      }
      _avatarToggleTimer = Timer(
        const Duration(milliseconds: _animationDuration),
        () {
          if (mounted) {
            animationController.forward();
          }
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _animationDuration),
    );
    getUserInfoAction();
  }

  @override
  void dispose() {
    animationController.dispose();
    isExpandedAvatar.dispose();
    userInfoNotifier.dispose();
    userInfoNotifierSub?.cancel();
    _setPermissionLevelSubscription?.cancel();
    _avatarToggleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProfileInfoBodyView(controller: this);
}
