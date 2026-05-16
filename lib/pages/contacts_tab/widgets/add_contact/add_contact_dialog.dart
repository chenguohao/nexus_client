import 'package:collection/collection.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog_view.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog_view_web.dart';
import 'package:fluffychat/presentation/extensions/contact/presentation_contact_extension.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_constant.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/zeon/pages/contact_preview/zeon_contact_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

Future<void> showAddContactDialog(
  BuildContext context, {
  String? displayName,
  String? matrixId,
}) {
  if (PlatformInfos.isMobile) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: ZeonColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return AddContactDialog(displayName: displayName, matrixId: matrixId);
      },
    );
  }

  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) {
      return Dialog(
        backgroundColor: ZeonColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: AddContactDialog(displayName: displayName, matrixId: matrixId),
      );
    },
  );
}

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key, this.displayName, this.matrixId});

  final String? displayName;
  final String? matrixId;

  @override
  State<AddContactDialog> createState() => AddContactDialogController();
}

class AddContactDialogController extends State<AddContactDialog> {
  /// 当前已登录账户所在的服务器域名（如 `zeon.chat`）。
  /// 加好友时把它当作默认 server，用户只需要输入 localpart。
  /// 未登录时为 null，此时退化为完整 mxid 输入。
  String? _defaultServerName;

  String? get defaultServerName => _defaultServerName;

  late final ValueNotifier<String> userName;

  final usernameErrorMessage = ValueNotifier<String?>(null);

  late final validateUsernameDebouncer = Debouncer<String?>(
    const Duration(milliseconds: 800),
    initialValue: null,
    onChanged: (value) {
      if (value == null || value.isEmpty) {
        usernameErrorMessage.value = null;
        return;
      }
      final mxid = resolvedMxid;
      if (!mxid.isValidMatrixId) {
        usernameErrorMessage.value = L10n.of(context)!.invalidUsername;
        return;
      }
      final localpartError = validateLocalpart(_localpart(mxid));
      if (localpartError != null) {
        usernameErrorMessage.value = localpartError;
        return;
      }
      usernameErrorMessage.value = null;
    },
  );

  /// 把用户输入解析成完整 mxid：
  /// - 已经以 `@` 开头 → 视为完整 mxid，原样返回（兼容多服务器）
  /// - 否则用 [defaultServerName] 拼接成 `@input:server`
  String get resolvedMxid {
    final input = userName.value.trim();
    if (input.isEmpty) return '';
    if (input.startsWith('@')) return input;
    final server = _defaultServerName;
    if (server == null || server.isEmpty) return input;
    return '@$input:$server';
  }

  /// 从 mxid 中提取 localpart（@ 和 : 之间的部分）。
  /// 例：`@alice123:zeon-im.com` → `alice123`
  static String _localpart(String mxid) {
    if (!mxid.startsWith('@')) return mxid;
    final colon = mxid.indexOf(':');
    return colon > 1 ? mxid.substring(1, colon) : mxid.substring(1);
  }

  /// Zeon ID localpart 规则：至少 6 位，只含字母或数字。
  static final _localpartPattern = RegExp(r'^[a-zA-Z0-9]{6,}$');

  /// 校验 localpart 是否符合规则。
  static String? validateLocalpart(String localpart) {
    if (localpart.isEmpty) return null;
    if (!_localpartPattern.hasMatch(localpart)) {
      return 'ID must be at least 6 letters or numbers.';
    }
    return null;
  }

  static String? _extractServerName(String? mxid) {
    if (mxid == null || !mxid.startsWith('@')) return null;
    final colonIndex = mxid.indexOf(':');
    return colonIndex < 0 ? null : mxid.substring(colonIndex + 1);
  }

  List<PresentationContact> get availableContacts =>
      getIt
          .get<ContactsManager>()
          .getContactsNotifier()
          .value
          .getSuccessOrNull<GetContactsSuccess>()
          ?.contacts
          .expand((contact) => contact.toPresentationContacts())
          .toList() ??
      [];

  void onUsernameChanged(String value) {
    userName.value = value;
    usernameErrorMessage.value = null;
    validateUsernameDebouncer.value = value;
  }

  /// 当前表单是否可提交：mxid 合法 + localpart 至少6位字母/数字
  bool get canSubmit {
    final mxid = resolvedMxid;
    if (!mxid.isValidMatrixId) return false;
    return validateLocalpart(_localpart(mxid)) == null;
  }

  Future<void> onSave() async {
    if (!canSubmit) return;

    final mxid = resolvedMxid;
    final client = Matrix.of(context).client;

    // 自加自己拦截
    if (mxid == client.userID) {
      usernameErrorMessage.value = 'Cannot add yourself.';
      return;
    }

    final existedContact = availableContacts.firstWhereOrNull(
      (contact) => contact.matrixId == mxid,
    );

    // 已是好友 → 直接打开聊天
    if (existedContact != null &&
        existedContact.friendStatus == FriendStatus.accepted) {
      chatWithUser(mxid, contact: existedContact);
      return;
    }

    // 已发出请求等对方处理 → 行内提示，不再发起
    if (existedContact != null &&
        existedContact.friendStatus == FriendStatus.pendingOutgoing) {
      usernameErrorMessage.value = 'You already sent a friend request to this user.';
      return;
    }

    // 对方已发请求等你处理 → 引导到通知（chat_invitation_body 那条邀请）
    if (existedContact != null &&
        existedContact.friendStatus == FriendStatus.pendingIncoming) {
      usernameErrorMessage.value =
          'This user has already sent you a friend request. Please respond from your messages.';
      return;
    }

    // 校验存在 + 拉取展示资料（名字 + 头像），然后跳到资料预览页让用户二次确认。
    // 真正的 /addressbook/request 调用延迟到用户在预览页主动点击「添加好友」时触发。
    final preview = await _fetchUserPreview(mxid);
    if (preview == null) return;

    if (!mounted) return;
    final matrixClient = Matrix.of(context).client;
    Navigator.of(context).pop(); // 先关掉 modal bottom sheet / dialog
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ZeonContactPreviewPage(
          mxid: mxid,
          initialDisplayName: preview.displayName,
          initialAvatarUri: preview.avatarUri,
          matrixClient: matrixClient,
        ),
      ),
    );
  }

  /// 调用 `client.getUserProfile()` 探测目标 mxid 是否真实存在，并取回
  /// 资料预览页的首屏数据（displayName + avatarUrl）。
  /// - 存在 → 返回 [_UserPreview]（displayName 没有时退化用 localpart；avatar 可空）
  /// - 服务器明确 404 (`M_NOT_FOUND`) → 返回 null 并把错误塞进 [usernameErrorMessage]
  /// - 其它异常（限流、网络）→ 返回 null 并显示通用错误
  ///
  /// 不在这里弹 snackbar，因为 modal bottom sheet 自身会盖住屏幕底部，
  /// 用户看不到 snackbar；行内错误才是该对话框唯一可靠的反馈通道。
  Future<_UserPreview?> _fetchUserPreview(String mxid) async {
    final client = Matrix.of(context).client;
    final result = await TwakeDialog.showFutureLoadingDialogFullScreen<
      ({String? displayName, Uri? avatarUrl, String? error})
    >(
      future: () async {
        try {
          final profile = await client.getUserProfile(mxid);
          return (
            displayName: profile.displayname,
            avatarUrl: profile.avatarUrl,
            error: null,
          );
        } on MatrixException catch (e) {
          if (e.error == MatrixError.M_NOT_FOUND) {
            return (
              displayName: null,
              avatarUrl: null,
              error: 'This user does not exist.',
            );
          }
          return (
            displayName: null,
            avatarUrl: null,
            error: 'Unable to verify user: ${e.errorMessage}',
          );
        } catch (_) {
          return (
            displayName: null,
            avatarUrl: null,
            error: 'Unable to verify user. Please try again.',
          );
        }
      },
    );
    final data = result.result;
    if (data == null || data.error != null) {
      usernameErrorMessage.value = data?.error ?? 'Unable to verify user.';
      return null;
    }
    // 如果对方没有设置 displayName，退化为用 localpart（@ 和 : 之间的部分）
    final localpart = mxid.contains(':')
        ? mxid.substring(1, mxid.indexOf(':'))
        : mxid.replaceFirst('@', '');
    final name = data.displayName?.isNotEmpty == true
        ? data.displayName!
        : localpart;
    return _UserPreview(displayName: name, avatarUri: data.avatarUrl);
  }

  void chatWithUser(String matrixId, {PresentationContact? contact}) {
    final existedRoomId = Matrix.of(
      context,
    ).client.getDirectChatFromUserId(matrixId);

    Navigator.pop(context);

    if (existedRoomId != null) {
      return context.go('/rooms/$existedRoomId');
    }

    Router.neglect(
      context,
      () => context.go(
        '/rooms/draftChat',
        extra: {
          PresentationContactConstant.receiverId: contact?.matrixId ?? '',
          PresentationContactConstant.displayName: contact?.displayName ?? '',
          PresentationContactConstant.status: '',
        },
      ),
    );
  }

  /// 长度限制 formatter，给昵称 / 钱包地址输入框复用
  static List<TextInputFormatter> lengthLimit(int max) => [
    LengthLimitingTextInputFormatter(max),
  ];

  @override
  void initState() {
    super.initState();
    // 如果外部传入的是完整 mxid（@user:server），保留原样让它走"完整模式"。
    // 如果传入的就是 localpart，原样塞进去也能正常拼装。
    userName = ValueNotifier(widget.matrixId ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _defaultServerName ??= _extractServerName(
      Matrix.of(context).client.userID,
    );
  }

  @override
  void dispose() {
    userName.dispose();
    usernameErrorMessage.dispose();
    validateUsernameDebouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformInfos.isMobile
        ? AddContactDialogView(controller: this)
        : AddContactDialogViewWeb(controller: this);
  }
}

/// 资料预览页首屏渲染所需的最小数据快照（在 dialog 这边一次性拉好）。
class _UserPreview {
  final String displayName;
  final Uri? avatarUri;

  const _UserPreview({required this.displayName, required this.avatarUri});
}
