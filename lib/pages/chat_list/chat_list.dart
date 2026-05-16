import 'dart:async';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:collection/collection.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/first_column_inner_routes.dart';
import 'package:fluffychat/di/global/dio_cache_interceptor_for_client.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/pages/bootstrap/bootstrap_dialog.dart';
import 'package:fluffychat/pages/chat_list/chat_custom_slidable_action.dart';
import 'package:fluffychat/pages/chat_list/chat_list_view_style.dart';
import 'package:fluffychat/presentation/mixins/comparable_presentation_contact_mixin.dart';
import 'package:fluffychat/pages/bootstrap/tom_bootstrap_dialog.dart';
import 'package:fluffychat/pages/chat_list/chat_list_view.dart';
import 'package:fluffychat/pages/settings_dashboard/settings_security/settings_security.dart';
import 'package:fluffychat/presentation/enum/chat_list/chat_list_enum.dart';
import 'package:fluffychat/presentation/extensions/client_extension.dart';
import 'package:fluffychat/presentation/mixins/go_to_group_chat_mixin.dart';
import 'package:fluffychat/presentation/model/chat_list/chat_selection_actions.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/extension/build_context_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:fluffychat/utils/tor_stub.dart'
    if (dart.library.html) 'package:tor_detector_web/tor_detector_web.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/context_menu/context_menu_action.dart';
import 'package:fluffychat/widgets/layouts/agruments/app_adaptive_scaffold_body_args.dart';
import 'package:fluffychat/widgets/layouts/agruments/logged_in_body_args.dart';
import 'package:fluffychat/widgets/layouts/agruments/logged_in_other_account_body_args.dart';
import 'package:fluffychat/widgets/mixins/popup_context_menu_action_mixin.dart';
import 'package:fluffychat/widgets/mixins/popup_menu_widget_mixin.dart';
import 'package:fluffychat/widgets/mixins/twake_context_menu_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../../utils/account_bundles.dart';
import '../../widgets/matrix.dart';
import 'package:fluffychat/zeon/widgets/zeon_dialog.dart';

class ChatList extends StatefulWidget {
  static BuildContext? contextForVoip;

  final ValueNotifier<String?> activeRoomIdNotifier;

  final Widget? bottomNavigationBar;

  final VoidCallback? onOpenSettings;

  final AbsAppAdaptiveScaffoldBodyArgs? adaptiveScaffoldBodyArgs;

  const ChatList({
    super.key,
    required this.activeRoomIdNotifier,
    this.bottomNavigationBar,
    this.onOpenSettings,
    this.adaptiveScaffoldBodyArgs,
  });

  @override
  ChatListController createState() => ChatListController();
}

class ChatListController extends State<ChatList>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        RouteAware,
        ComparablePresentationContactMixin,
        PopupContextMenuActionMixin,
        PopupMenuWidgetMixin,
        GoToGroupChatMixin,
        TwakeContextMenuMixin {
  final responsive = getIt.get<ResponsiveUtils>();

  final ValueNotifier<bool> expandRoomsForAllNotifier = ValueNotifier(true);

  final ValueNotifier<bool> expandRoomsForPinNotifier = ValueNotifier(true);

  final ValueNotifier<bool> sortingRoomsNotifier = ValueNotifier(true);

  final ValueNotifier<SelectMode> selectModeNotifier = ValueNotifier(
    SelectMode.normal,
  );

  final ValueNotifier<List<ConversationSelectionPresentation>>
  conversationSelectionNotifier = ValueNotifier([]);

  final TextEditingController searchChatController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  final StreamController<Client> _clientStream = StreamController.broadcast();

  StreamSubscription? _roomUpdateSubscription;

  String? activeSpaceId;

  Future<QueryPublicRoomsResponse>? publicRoomsResponse;

  SearchUserDirectoryResponse? userSearchResult;

  QueryPublicRoomsResponse? roomSearchResult;

  bool isTorBrowser = false;

  bool scrolledToTop = true;

  Client get activeClient => matrixState.client;

  MatrixState get matrixState => Matrix.of(context);

  ActiveFilter activeFilter = AppConfig.separateChatTypes
      ? ActiveFilter.messages
      : ActiveFilter.allChats;

  List<Room> get _filteredRooms {
    final rooms = activeClient.filteredRoomsForAll(activeFilter);
    final after = _applyZeonHideOutgoingPendingDms(rooms);
    // 无任何 Tom 好友快照（磁盘也没有）时，通讯录 Initial 会剔除全部 DM；
    // 此时仍需露出 Matrix 缓存会话以免误判欢迎页。但一旦已有快照却仍筛空，
    // 说明会话均应隐藏（如 outbound pending），禁止退回 raw，否则会短暂露出 pending。
    if (after.isEmpty && rooms.isNotEmpty) {
      final snapshot =
          getIt.get<ContactsManager>().getContactsNotifier().value;
      GetContactsSuccess? tomSuccess =
          snapshot.getSuccessOrNull<GetContactsSuccess>();
      tomSuccess ??=
          getIt.get<ContactsManager>().lastSuccessfulTomContactsSnapshot;
      if (tomSuccess != null) {
        return after;
      }
      return rooms;
    }
    return after;
  }

  /// 我发出好友申请后建的 DM：对方未接受（pending_outgoing）或已拒绝（rejected）时
  /// 不显示在聊天列表，只在通讯录「发出的请求」里可见。
  ///
  /// 在 Tom 通讯录快照尚未就绪（Initial / Loading）时**先不展示任何 DM**，避免
  /// Matrix 已同步出房间、但 `friendStatusByMxid` 未到导致的 pending 会话闪现/空列表来回跳。
  ///
  /// 若通讯录 notifier 因 `reSyncContacts` / Loading 处于瞬时非成功态，但本地已有
  /// [ContactsManager.lastSuccessfulTomContactsSnapshot]，则用该快照继续过滤，
  /// 避免私聊会话被整批隐藏触发首页欢迎页闪烁。
  List<Room> _applyZeonHideOutgoingPendingDms(List<Room> rooms) {
    final snapshot =
        getIt.get<ContactsManager>().getContactsNotifier().value;
    GetContactsSuccess? tomSuccess =
        snapshot.getSuccessOrNull<GetContactsSuccess>();
    tomSuccess ??=
        getIt.get<ContactsManager>().lastSuccessfulTomContactsSnapshot;

    if (tomSuccess == null) {
      final hideDirectChatsUntilTomReady = snapshot.fold(
        (failure) => failure is GetContactsIsEmpty,
        (success) =>
            success is ContactsInitial || success is ContactsLoading,
      );
      if (hideDirectChatsUntilTomReady) {
        return rooms.where((room) => !room.isDirectChat).toList();
      }
      return rooms;
    }

    final statusMap = tomSuccess.friendStatusByMxid;
    return rooms
        .where(
          (room) =>
              !_shouldHideZeonOutboundPendingOrRejectedDm(room, statusMap),
        )
        .toList();
  }

  static bool _shouldHideZeonOutboundPendingOrRejectedDm(
    Room room,
    Map<String, FriendStatus> statusMap,
  ) {
    if (!room.isDirectChat) return false;
    final peer = room.directChatMatrixID;
    if (peer == null || peer.isEmpty) return false;
    final st = statusMap[peer];
    return st == FriendStatus.pendingOutgoing || st == FriendStatus.rejected;
  }

  List<Room> get filteredRoomsForAll =>
      _filteredRooms.where((room) => !room.isFavourite).toList();

  List<Room> get filteredRoomsForPin =>
      _filteredRooms.where((room) => room.isFavourite).toList();

  bool get displayNavigationBar => false;

  Stream<Client> get clientStream => _clientStream.stream;

  // Needs to match GroupsSpacesEntry for 'separate group' checking.
  List<Room> get spaces => activeClient.rooms.where((r) => r.isSpace).toList();

  ValueNotifier<String?> activeRoomIdNotifier = ValueNotifier(null);

  bool get isSelectMode => selectModeNotifier.value == SelectMode.select;

  bool get anySelectedRoomNotMarkedUnread => conversationSelectionNotifier.value
      .any((conversation) => !_containUnreadMessage(conversation));

  bool _containUnreadMessage(ConversationSelectionPresentation conversation) {
    final room = Matrix.of(context).client.getRoomById(conversation.roomId);
    return room != null && (room.isUnreadOrInvited || room.hasNewMessages);
  }

  bool get anySelectedRoomNotFavorite =>
      conversationSelectionNotifier.value.any(
        (conversation) => !Matrix.of(
          context,
        ).client.getRoomById(conversation.roomId)!.isFavourite,
      );

  bool get anySelectedRoomNotMuted => conversationSelectionNotifier.value.any(
    (conversation) =>
        Matrix.of(
          context,
        ).client.getRoomById(conversation.roomId)!.pushRuleState ==
        PushRuleState.notify,
  );

  bool get displayBundles =>
      Matrix.of(context).hasComplexBundles &&
      Matrix.of(context).accountBundles.keys.length > 1;

  bool get filteredRoomsForAllIsEmpty => filteredRoomsForAll.isEmpty;

  bool get filteredRoomsForPinIsEmpty => filteredRoomsForPin.isEmpty;

  /// 是否显示「Welcome / 引导」大空状态：仅以 Matrix 本地会话为准（不经 Zeon DM 隐藏）。
  /// 避免通讯录尚未返回时把私聊全藏起来而误当成新用户。
  bool get chatListShowsOnboardingWelcome =>
      activeClient.filteredRoomsForAll(activeFilter).isEmpty;

  bool get conversationSelectionNotifierIsEmpty =>
      conversationSelectionNotifier.value.isEmpty;

  PushRuleState get pushRuleState => anySelectedRoomNotMuted
      ? PushRuleState.mentionsOnly
      : PushRuleState.notify;

  void addAccountAction() => context.go('/settings/account');

  void _onScroll() {
    final newScrolledToTop = scrollController.position.pixels <= 0;
    if (newScrolledToTop != scrolledToTop) {
      setState(() {
        scrolledToTop = newScrolledToTop;
      });
    }
  }

  void editSpace(BuildContext context, String spaceId) async {
    await activeClient.getRoomById(spaceId)!.postLoad();
    if (mounted) {
      context.go('/spaces/$spaceId');
    }
  }

  String? get secureActiveBundle {
    if (Matrix.of(context).activeBundle == null ||
        !Matrix.of(
          context,
        ).accountBundles.keys.contains(Matrix.of(context).activeBundle)) {
      return Matrix.of(context).accountBundles.keys.first;
    }
    return Matrix.of(context).activeBundle;
  }

  void toggleSelection(String roomId) {
    final conversation = conversationSelectionNotifier.value.firstWhereOrNull(
      (conversation) => conversation.roomId == roomId,
    );

    final Set<ConversationSelectionPresentation>
    tempConversationSelectionPresentation = conversationSelectionNotifier.value
        .toSet();

    if (conversation != null && conversation.isSelected) {
      tempConversationSelectionPresentation.remove(conversation);
      if (tempConversationSelectionPresentation.isEmpty) {
        toggleSelectMode();
      }
    } else {
      tempConversationSelectionPresentation.add(
        ConversationSelectionPresentation(
          roomId: roomId,
          selectionType: SelectionType.selected,
        ),
      );
    }

    conversationSelectionNotifier.value = tempConversationSelectionPresentation
        .toList();
  }

  void toggleSelectMode() {
    selectModeNotifier.value = isSelectMode
        ? SelectMode.normal
        : SelectMode.select;
    _clearSelectionItem();
  }

  Future<void> actionWithToggleSelectMode(Function action) async {
    await action();
    toggleSelectMode();
  }

  void _clearSelectionItem() {
    conversationSelectionNotifier.value = [];
  }

  void onClickClearSelection() {
    toggleSelectMode();
  }

  void resetActiveSpaceId() {
    setState(() {
      activeSpaceId = null;
    });
  }

  void setActiveSpace(String? spaceId) {
    setState(() {
      activeSpaceId = spaceId;
    });
  }

  Future<void> toggleUnreadSelections() async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        final markUnreadAction = anySelectedRoomNotMarkedUnread;
        for (final conversation in conversationSelectionNotifier.value) {
          final room = activeClient.getRoomById(conversation.roomId)!;
          if (!markUnreadAction) {
            await _markAsRead(room);
          }

          await room.markUnread(markUnreadAction);
        }
      },
    );
  }

  Future<void> _markAsRead(Room room) async {
    if (room.isUnread || room.hasNewMessages) {
      await room.setReadMarker(
        room.lastEvent!.eventId,
        mRead: room.lastEvent!.eventId,
      );
    }
  }

  Future<void> toggleFavouriteRoom() async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        final makeFavorite = anySelectedRoomNotFavorite;
        for (final conversation in conversationSelectionNotifier.value) {
          final room = activeClient.getRoomById(conversation.roomId)!;
          if (room.isFavourite == makeFavorite) continue;
          await activeClient
              .getRoomById(conversation.roomId)!
              .setFavourite(makeFavorite);
        }
      },
    );
  }

  Future<void> toggleMutedSelections() async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        final newRuleState = pushRuleState;
        for (final conversation in conversationSelectionNotifier.value) {
          final room = activeClient.getRoomById(conversation.roomId)!;
          if (room.pushRuleState == newRuleState) continue;
          await activeClient
              .getRoomById(conversation.roomId)!
              .setPushRuleState(newRuleState);
        }
      },
    );
  }

  Future<void> archiveAction() async {
    final confirmed = await ZeonDialog.confirm(
      context,
      title: L10n.of(context)!.areYouSure,
      okLabel: L10n.of(context)!.yes,
      cancelLabel: L10n.of(context)!.cancel,
      destructive: true,
      useRootNavigator: false,
    );
    if (!confirmed) return;
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () => _archiveSelectedRooms(),
    );
    setState(() {});
  }

  void setStatus() async {
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context)!.setStatus,
      okLabel: L10n.of(context)!.ok,
      cancelLabel: L10n.of(context)!.cancel,
      textFields: [
        DialogTextField(hintText: L10n.of(context)!.statusExampleMessage),
      ],
    );
    if (input == null) return;
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () => activeClient.setPresence(
        activeClient.userID!,
        PresenceType.online,
        statusMsg: input.single,
      ),
    );
  }

  Future<void> _archiveSelectedRooms() async {
    while (conversationSelectionNotifier.value.isNotEmpty) {
      final conversation = conversationSelectionNotifier.value.first;
      try {
        await activeClient.getRoomById(conversation.roomId)!.leave();
      } finally {
        toggleSelection(conversation.roomId);
      }
    }
  }

  Future<void> addToSpace() async {
    final selectedSpace = await showConfirmationDialog<String>(
      context: context,
      title: L10n.of(context)!.addToSpace,
      message: L10n.of(context)!.addToSpaceDescription,
      fullyCapitalizedForMaterial: false,
      actions: Matrix.of(context).client.rooms
          .where((r) => r.isSpace)
          .map(
            (space) => AlertDialogAction(
              key: space.id,
              label: space.getLocalizedDisplayname(
                MatrixLocals(L10n.of(context)!),
              ),
            ),
          )
          .toList(),
    );
    if (selectedSpace == null) return;
    final result = await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        final space = activeClient.getRoomById(selectedSpace)!;
        if (space.canSendDefaultStates) {
          for (final conversation in conversationSelectionNotifier.value) {
            await space.setSpaceChild(conversation.roomId);
          }
        }
      },
    );
    if (result.error == null) {
      if (!mounted) return;
      TwakeSnackBar.show(
        context,
        L10n.of(context)!.chatHasBeenAddedToThisSpace,
      );
    }

    conversationSelectionNotifier.value.clear();
  }

  Future<void> setupAdditionalDioCacheOption(String userId) async {
    Logs().d('ChatList::setupAdditionalDioCacheOption: $userId');
    DioCacheInterceptorForClient(userId).setup(getIt);
  }

  Future<void> _trySync() async {
    final args = widget.adaptiveScaffoldBodyArgs;
    if (args is LoggedInBodyArgs || args is LoggedInOtherAccountBodyArgs) {
      Logs().i(
        '[ZeonDiag][ChatList] _trySync → _waitForFirstSyncAfterLogin '
        '(args=${args.runtimeType})',
      );
      _waitForFirstSyncAfterLogin();
    } else {
      Logs().i(
        '[ZeonDiag][ChatList] _trySync → _waitForFirstSync '
        '(args=${args?.runtimeType ?? 'null'})',
      );
      _waitForFirstSync();
    }
  }

  Future<void> _waitForFirstSyncAfterLogin() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Logs().i(
        '[ZeonDiag][ChatList] _waitForFirstSyncAfterLogin start '
        'user=${activeClient.userID} prevBatchSet=${activeClient.prevBatch != null} '
        'matrixWaitFS=${matrixState.waitForFirstSync}',
      );
      final result = await TomBootstrapDialog(
        client: activeClient,
      ).show(context);

      setState(() {});

      if (result == false) {
        await BootstrapDialog(client: activeClient).show();
      }

      await activeClient.roomsLoading;
      await activeClient.accountDataLoading;
      if (activeClient.userID != null) {
        await setupAdditionalDioCacheOption(activeClient.userID!);
      }
      if (!mounted) return;
      if (activeClient.isLogged() && activeClient.prevBatch == null) {
        Logs().w(
          '[ZeonDiag][ChatList] AfterLogin: prevBatch null — oneShotSync',
        );
        try {
          await activeClient.oneShotSync(timeout: Duration.zero);
        } catch (e, st) {
          Logs().w('[ZeonDiag][ChatList] oneShotSync: $e\n$st');
        }
      }
      if (!mounted) return;
      Logs().i(
        '[ZeonDiag][ChatList] _waitForFirstSyncAfterLogin before setState '
        'prevBatchSet=${activeClient.prevBatch != null}',
      );
      setState(() {
        matrixState.waitForFirstSync = true;
        matrixState.handleShowQrCodeDownload(_filteredRooms.isEmpty);
      });

      // Process cached sharing intents after first sync
      matrixState.processCachedSharingIntents();
    });
  }

  Future<void> _waitForFirstSync() async {
    // Zeon (and similar) use `Client.init(waitForFirstSync: false)` so login
    // returns before the first /sync finishes; `roomsLoading` is only the
    // initial DB read from init and completes with `prevBatch` still null.
    // Without awaiting the in-flight first sync, we set `waitForFirstSync`
    // below too early: ChatListBodyView then shows the skeleton until
    // `prevBatch != null`, but its StreamBuilder listens only to sync updates
    // with `hasRoomUpdate` — a brand-new account may get none, so the UI
    // never rebuilds until app restart (when prev_batch is loaded from disk).
    Logs().i(
      '[ZeonDiag][ChatList] _waitForFirstSync start '
      'user=${activeClient.userID} '
      'prevBatchSet=${activeClient.prevBatch != null} '
      'firstSyncFutureNull=${activeClient.firstSyncReceived == null}',
    );
    final firstSync = activeClient.firstSyncReceived;
    if (firstSync != null) {
      try {
        await firstSync;
      } catch (e, st) {
        Logs().w('[ZeonDiag][ChatList] firstSyncReceived error: $e\n$st');
        rethrow;
      }
    } else {
      Logs().w(
        '[ZeonDiag][ChatList] firstSyncReceived is null — skipping await '
        '(unexpected after login)',
      );
    }
    Logs().i(
      '[ZeonDiag][ChatList] _waitForFirstSync after firstSync '
      'prevBatchSet=${activeClient.prevBatch != null}',
    );
    // `_innerSync` can return without setting `prevBatch` if the SDK drops a
    // stale sync response ("Current sync request ID has changed"). The
    // `firstSyncReceived` future still completes — force another sync pass.
    if (activeClient.isLogged() && activeClient.prevBatch == null) {
      Logs().w(
        '[ZeonDiag][ChatList] prevBatch still null after firstSync — '
        'calling oneShotSync',
      );
      try {
        await activeClient.oneShotSync(timeout: Duration.zero);
      } catch (e, st) {
        Logs().w('[ZeonDiag][ChatList] oneShotSync failed: $e\n$st');
      }
      Logs().i(
        '[ZeonDiag][ChatList] after oneShotSync '
        'prevBatchSet=${activeClient.prevBatch != null}',
      );
    }
    await activeClient.roomsLoading;
    await activeClient.accountDataLoading;
    if (activeClient.userID != null) {
      await setupAdditionalDioCacheOption(activeClient.userID!);
    }
    if (!mounted) return;
    Logs().i(
      '[ZeonDiag][ChatList] _waitForFirstSync before setState(waitFS=true) '
      'prevBatchSet=${activeClient.prevBatch != null} rooms=${_filteredRooms.length}',
    );
    setState(() {
      matrixState.waitForFirstSync = true;
      matrixState.handleShowQrCodeDownload(_filteredRooms.isEmpty);
    });

    // Process cached sharing intents after first sync
    matrixState.processCachedSharingIntents();
  }

  void editBundlesForAccount(String? userId, String? activeBundle) async {
    final l10n = L10n.of(context)!;
    final client = Matrix.of(
      context,
    ).widget.clients[Matrix.of(context).getClientIndexByMatrixId(userId!)];
    final action = await showConfirmationDialog<EditBundleAction>(
      context: context,
      title: L10n.of(context)!.editBundlesForAccount,
      actions: [
        AlertDialogAction(
          key: EditBundleAction.addToBundle,
          label: L10n.of(context)!.addToBundle,
        ),
        if (activeBundle != client.userID)
          AlertDialogAction(
            key: EditBundleAction.removeFromBundle,
            label: L10n.of(context)!.removeFromBundle,
          ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case EditBundleAction.addToBundle:
        final bundle = await showTextInputDialog(
          context: context,
          title: l10n.bundleName,
          textFields: [DialogTextField(hintText: l10n.bundleName)],
        );
        if (bundle == null || bundle.isEmpty || bundle.single.isEmpty) return;
        await TwakeDialog.showFutureLoadingDialogFullScreen(
          future: () => client.setAccountBundle(bundle.single),
        );
        break;
      case EditBundleAction.removeFromBundle:
        await TwakeDialog.showFutureLoadingDialogFullScreen(
          future: () => client.removeFromAccountBundle(activeBundle!),
        );
    }
  }

  void _onTapBottomNavigation(
    ChatListSelectionActions chatListBottomNavigatorBar,
  ) async {
    switch (chatListBottomNavigatorBar) {
      case ChatListSelectionActions.read:
        await actionWithToggleSelectMode(toggleUnreadSelections);
        return;
      case ChatListSelectionActions.mute:
        await actionWithToggleSelectMode(toggleMutedSelections);
        return;
      case ChatListSelectionActions.pin:
        await actionWithToggleSelectMode(toggleFavouriteRoom);
        return;
      case ChatListSelectionActions.more:
        await actionWithToggleSelectMode(
          () => {TwakeSnackBar.show(context, 'Not implemented yet')},
        );
        return;
    }
  }

  void handleContextMenuAction(
    BuildContext context,
    Room room,
    TapDownDetails details,
  ) async {
    disableRightClick();
    final offset = details.globalPosition;
    final listPopupActions = _popupMenuActions(room);
    final listContextActions = _mapPopupMenuActionsToContextMenuActions(
      context,
      room,
      listPopupActions,
    );
    final selectedActionIndex = await showTwakeContextMenu(
      offset: offset,
      context: context,
      listActions: listContextActions,
    );
    enableRightClick();
    if (selectedActionIndex != null && selectedActionIndex is int) {
      _handleClickOnContextMenuItem(
        listPopupActions[selectedActionIndex],
        room,
      );
    }
  }

  List<ChatListSelectionActions> _popupMenuActions(Room room) {
    final listAction = [
      if (!room.isInvitation) ...[
        ChatListSelectionActions.read,
        ChatListSelectionActions.pin,
      ],
      ChatListSelectionActions.mute,
    ];
    return listAction;
  }

  List<ContextMenuAction> _mapPopupMenuActionsToContextMenuActions(
    BuildContext context,
    Room room,
    List<ChatListSelectionActions> listActions,
  ) {
    return listActions.map((action) {
      return ContextMenuAction(
        name: action.getTitleContextMenuSelection(context, room),
        icon: action.getIconContextMenuSelection(room),
      );
    }).toList();
  }

  void _handleClickOnContextMenuItem(
    ChatListSelectionActions action,
    Room room,
  ) async {
    switch (action) {
      case ChatListSelectionActions.read:
        await toggleRead(room);
        return;
      case ChatListSelectionActions.pin:
        await togglePin(room);
        return;
      case ChatListSelectionActions.mute:
        await toggleMuteRoom(room);
        return;
      case ChatListSelectionActions.more:
        return;
    }
  }

  Future<void> toggleRead(Room room) async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        if (room.isUnread) {
          await room.markUnread(false);
          await room.setReadMarker(
            room.lastEvent!.eventId,
            mRead: room.lastEvent!.eventId,
          );
        } else {
          await room.markUnread(true);
        }
      },
    );
  }

  Future<void> togglePin(Room room) async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        await room.setFavourite(!room.isFavourite);
      },
    );
  }

  Future<void> toggleMuteRoom(Room room) async {
    await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () async {
        if (room.isMuted) {
          await room.unmute();
        } else {
          await room.mute();
        }
      },
    );
  }

  List<ChatListSelectionActions> _getNavigationDestinations() {
    return [
      ChatListSelectionActions.read,
      ChatListSelectionActions.mute,
      ChatListSelectionActions.pin,
      //TODO: Enable when more action is implemented
      // ChatListSelectionActions.more,
    ];
  }

  List<Widget> bottomNavigationActionsWidget({
    required EdgeInsetsDirectional paddingIcon,
    double? width,
    double? iconSize,
  }) {
    return _getNavigationDestinations().map((item) {
      return InkWell(
        onTap: () => _onTapBottomNavigation(item),
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Padding(
                padding: paddingIcon,
                child: Icon(
                  item.getIconBottomNavigation(),
                  size: iconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                _getTitleBottomNavigation(item),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _getTitleBottomNavigation(
    ChatListSelectionActions actionBottomNavigation,
  ) {
    switch (actionBottomNavigation) {
      case ChatListSelectionActions.read:
        if (anySelectedRoomNotMarkedUnread) {
          return L10n.of(context)!.unread;
        } else {
          return L10n.of(context)!.read;
        }
      case ChatListSelectionActions.mute:
        if (anySelectedRoomNotMuted) {
          return L10n.of(context)!.mute;
        } else {
          return L10n.of(context)!.unmute;
        }
      case ChatListSelectionActions.pin:
        if (anySelectedRoomNotFavorite) {
          return L10n.of(context)!.pin;
        } else {
          return L10n.of(context)!.unpin;
        }
      case ChatListSelectionActions.more:
        return L10n.of(context)!.more;
    }
  }

  void _hackyWebRTCFixForWeb() {
    ChatList.contextForVoip = context;
  }

  Future<void> _checkTorBrowser() async {
    if (!kIsWeb) return;
    final isTor = await TorBrowserDetector.isTorBrowser;
    isTorBrowser = isTor;
  }

  Future<void> dehydrate() =>
      SettingsSecurityController.dehydrateDevice(context);

  void onLongPressChatListItem(Room room) {
    if (!isSelectMode) {
      toggleSelectMode();
      _handleOnLongPressInSelectMode(room);
    }
  }

  void _handleOnLongPressInSelectMode(Room room) {
    if (conversationSelectionNotifierIsEmpty) {
      toggleSelection(room.id);
    }
  }

  void goToNewPrivateChat() {
    if (FirstColumnInnerRoutes.instance.goRouteAvailableInFirstColumn()) {
      context.go('/rooms/newprivatechat');
    } else {
      context.pushInner('innernavigator/newprivatechat');
    }
  }

  void onClickAvatar() {
    context.push('/rooms/profile');
  }

  void _handleRecovery() {
    if (widget.adaptiveScaffoldBodyArgs is LoggedInOtherAccountBodyArgs) {
      Logs().d(
        "ChatList::_handleAnotherAccountAdded(): Handle recovery data for another account",
      );
      if (!matrixState.waitForFirstSync) {
        _trySync();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatList oldWidget) {
    Logs().d(
      "ChatList::didUpdateWidget(): Old Args ${oldWidget.adaptiveScaffoldBodyArgs} - UserId ${oldWidget.adaptiveScaffoldBodyArgs?.newActiveClient?.userID}",
    );
    final newActiveClient = widget.adaptiveScaffoldBodyArgs?.newActiveClient;
    Logs().d(
      "ChatList::didUpdateWidget(): New Args ${widget.adaptiveScaffoldBodyArgs} - UserId ${newActiveClient?.userID}",
    );
    if (newActiveClient != null && newActiveClient.userID != null) {
      setState(() {
        _clientStream.add(newActiveClient);
        _handleRecovery();
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    activeRoomIdNotifier.value = widget.activeRoomIdNotifier.value;
    scrollController.addListener(_onScroll);
    _listenToRoomUpdates();
    Logs().i(
      '[ZeonDiag][ChatList] initState '
      'args=${widget.adaptiveScaffoldBodyArgs?.runtimeType ?? 'null'} '
      'user=${activeClient.userID} clientName=${activeClient.clientName} '
      'prevBatchSet=${activeClient.prevBatch != null} '
      'matrixWaitFS=${matrixState.waitForFirstSync} '
      'firstSyncNull=${activeClient.firstSyncReceived == null}',
    );
    if (!matrixState.waitForFirstSync) {
      _trySync();
    } else if (activeClient.prevBatch == null) {
      // Stale global flag (e.g. kept-alive + new session) would skip _trySync
      // and trap the list on the skeleton forever.
      Logs().w(
        '[ZeonDiag][ChatList] initState: matrixWaitFS=true but prevBatch=null '
        '— resetting waitFS and running _trySync',
      );
      matrixState.waitForFirstSync = false;
      _trySync();
    } else {
      Logs().i(
        '[ZeonDiag][ChatList] initState: skipped _trySync (already synced UI flag)',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Logs().i(
        '[ZeonDiag][ChatList] postFrame init '
        'prevBatchSet=${activeClient.prevBatch != null} '
        'matrixWaitFS=${matrixState.waitForFirstSync}',
      );
    });
    _hackyWebRTCFixForWeb();
    // TODO: 28Dec2023 Disable callkeep for util we support audio/video calls
    // CallKeepManager().initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        Matrix.of(context).backgroundPush?.setupPush();
      }
    });
    _checkTorBrowser();
    super.initState();
  }

  void onOpenSearchPageInMultipleColumns() {
    if (!FirstColumnInnerRoutes.instance.goRouteAvailableInFirstColumn()) {
      context.pushInner('innernavigator/search');
    }
  }

  List<Widget> getSlidables(BuildContext context, Room room) {
    return [
      if (!room.isInvitation)
        ChatCustomSlidableAction(
          label: room.isUnread
              ? L10n.of(context)!.read
              : L10n.of(context)!.unread,
          icon: Icon(
            room.isUnread
                ? Icons.mark_chat_read_outlined
                : Icons.mark_chat_unread_outlined,
            size: ChatListViewStyle.slidableIconSize,
          ),
          onPressed: (_) => toggleRead(room),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: ChatListViewStyle.readSlidableColor(room.isUnread)!,
        ),
      ChatCustomSlidableAction(
        label: room.isMuted ? L10n.of(context)!.unmute : L10n.of(context)!.mute,
        icon: Icon(
          room.isMuted
              ? Icons.notifications_on_outlined
              : Icons.notifications_off_outlined,
          size: ChatListViewStyle.slidableIconSize,
        ),
        onPressed: (_) => toggleMuteRoom(room),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        backgroundColor: ChatListViewStyle.muteSlidableColor(room.isMuted)!,
      ),
      if (!room.isInvitation)
        ChatCustomSlidableAction(
          label: room.isFavourite
              ? L10n.of(context)!.unpin
              : L10n.of(context)!.pin,
          icon: room.isFavourite
              ? SvgPicture.asset(
                  ImagePaths.icUnpin,
                  width: ChatListViewStyle.slidableIconSize,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onPrimary,
                    BlendMode.srcIn,
                  ),
                )
              : const Icon(
                  Icons.push_pin_outlined,
                  size: ChatListViewStyle.slidableIconSize,
                ),
          onPressed: (_) => togglePin(room),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: ChatListViewStyle.pinSlidableColor(
            room.isFavourite,
          )!,
        ),
    ];
  }

  void _listenToRoomUpdates() {
    _roomUpdateSubscription = activeClient.onSync.stream
        .where((s) => s.hasRoomUpdate)
        .listen((syncUpdated) {
          if (syncUpdated.hasRoomUpdate) {
            if (_filteredRooms.length > 2) return;
            matrixState.handleShowQrCodeDownload(_filteredRooms.isEmpty);
          }
        });
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    _roomUpdateSubscription?.cancel();
    expandRoomsForAllNotifier.dispose();
    expandRoomsForPinNotifier.dispose();
    selectModeNotifier.dispose();
    conversationSelectionNotifier.dispose();
    searchChatController.dispose();
    scrollController.dispose();
    _clientStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ChatListView(
      controller: this,
      bottomNavigationBar: widget.bottomNavigationBar,
      onOpenSearchPageInMultipleColumns: onOpenSearchPageInMultipleColumns,
      onTapBottomNavigation: _onTapBottomNavigation,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

enum EditBundleAction { addToBundle, removeFromBundle }
