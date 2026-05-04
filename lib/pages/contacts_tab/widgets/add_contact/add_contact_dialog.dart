import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/data/model/addressbook/address_book.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/app_state/contact/post_address_book_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/extensions/contact/address_book_extension.dart';
import 'package:fluffychat/domain/usecase/contacts/post_address_book_interactor.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat_profile_info/chat_profile_info_navigator.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog_view.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog_view_web.dart';
import 'package:fluffychat/presentation/extensions/contact/presentation_contact_extension.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_constant.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/cupertino.dart';
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
  /// 备注昵称最大长度（防止 displayName 撑爆 UI）
  static const int nicknameMaxLength = 32;

  /// 当前已登录账户所在的服务器域名（如 `zeon.chat`）。
  /// 加好友时把它当作默认 server，用户只需要输入 localpart。
  /// 未登录时为 null，此时退化为完整 mxid 输入。
  String? _defaultServerName;

  String? get defaultServerName => _defaultServerName;

  late final ValueNotifier<String> nickname;
  late final ValueNotifier<String> userName;

  final usernameErrorMessage = ValueNotifier<String?>(null);

  late final validateUsernameDebouncer = Debouncer<String?>(
    const Duration(milliseconds: 1200),
    initialValue: null,
    onChanged: (value) {
      if (value == null || value.isEmpty) {
        usernameErrorMessage.value = null;
        return;
      }
      if (resolvedMxid.isValidMatrixId) {
        usernameErrorMessage.value = null;
      } else {
        usernameErrorMessage.value = L10n.of(context)!.invalidUsername;
      }
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

  void onNicknameChanged(String value) => nickname.value = value;

  /// 当前表单是否可提交：昵称非空 + mxid 合法（拼上默认 server 后）
  bool get canSubmit =>
      nickname.value.trim().isNotEmpty && resolvedMxid.isValidMatrixId;

  Future<void> onSave() async {
    if (!canSubmit) return;

    final mxid = resolvedMxid;
    final existedContact = availableContacts.firstWhereOrNull(
      (contact) => contact.matrixId == mxid,
    );

    if (existedContact == null) {
      // 预检：确认这个 mxid 在服务器上是真实存在的。
      // 失败时把错误塞进 [usernameErrorMessage]，对话框会在 ZEON ID 输入框
      // 下方直接显红字（snackbar 在 modal bottom sheet 里会被 sheet 自身遮住，
      // 用户看不到）。
      final exists = await _verifyUserExists(mxid);
      if (!exists) return;

      final result =
          await TwakeDialog.showFutureLoadingDialogFullScreen<
            Either<Failure, Success>
          >(
            future: () => getIt
                .get<PostAddressBookInteractor>()
                .execute(
                  addressBooks: [
                    AddressBook(
                      mxid: mxid,
                      displayName: nickname.value.trim(),
                    ),
                  ],
                )
                .last,
          );
      final state = result.result?.fold(
        (failure) => failure,
        (success) => success,
      );
      if (state is PostAddressBookFailureState) {
        TwakeSnackBar.show(context, state.exception.toString());
        return;
      } else if (state is PostAddressBookSuccessState) {
        getIt.get<ContactsManager>().refreshTomContacts(
          Matrix.of(context).client,
        );
        final createdContact = state.updatedAddressBooks.firstOrNull
            ?.toPresentationContact()
            .firstOrNull;
        if (PlatformInfos.isMobile) {
          Navigator.pop(context);
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ChatProfileInfoNavigator(
                isInStack: true,
                onBack: context.pop,
                contact: createdContact,
              ),
            ),
          );
        } else {
          chatWithUser(mxid, contact: createdContact);
        }
      }
      return;
    }

    chatWithUser(mxid, contact: existedContact);
  }

  /// 调用 `client.getUserProfile()` 探测目标 mxid 是否真实存在。
  /// - 存在 → 返回 true
  /// - 服务器明确 404 (`M_NOT_FOUND`) → 返回 false 并把错误塞进
  ///   [usernameErrorMessage]，UI 会在输入框下方直接显红字
  /// - 其它异常（限流、网络）→ 返回 false 并显示通用错误
  ///
  /// 不在这里弹 snackbar，因为 modal bottom sheet 自身会盖住屏幕底部，
  /// 用户看不到 snackbar；行内错误才是该对话框唯一可靠的反馈通道。
  Future<bool> _verifyUserExists(String mxid) async {
    final client = Matrix.of(context).client;
    final result =
        await TwakeDialog.showFutureLoadingDialogFullScreen<String?>(
          future: () async {
            try {
              await client.getUserProfile(mxid);
              return null; // 存在
            } on MatrixException catch (e) {
              if (e.error == MatrixError.M_NOT_FOUND) {
                return 'This user does not exist.';
              }
              return 'Unable to verify user: ${e.errorMessage}';
            } catch (_) {
              return 'Unable to verify user. Please try again.';
            }
          },
        );
    final errorMessage = result.result;
    if (errorMessage != null) {
      usernameErrorMessage.value = errorMessage;
      return false;
    }
    return true;
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
    nickname = ValueNotifier(widget.displayName ?? '');
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
    nickname.dispose();
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
