import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/pages/chat/add_contact_banner.dart';
import 'package:fluffychat/pages/chat/blocked_message_view.dart';
import 'package:fluffychat/pages/chat/blocked_user_banner.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_title_style.dart';
import 'package:fluffychat/pages/chat/chat_background.dart';
import 'package:fluffychat/pages/chat/chat_view_body_style.dart';
import 'package:fluffychat/pages/chat/chat_view_style.dart';
import 'package:fluffychat/pages/chat_draft/draft_chat.dart';
import 'package:fluffychat/pages/chat_draft/draft_chat_empty_widget.dart';
import 'package:fluffychat/pages/chat_draft/draft_chat_input_row.dart';
import 'package:fluffychat/pages/chat_draft/draft_chat_view_style.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/android_utils.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/string_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_emoji_mart/flutter_emoji_mart.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:matrix/matrix.dart';

class DraftChatView extends StatelessWidget {
  const DraftChatView({super.key, required this.controller});

  final DraftChatController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isSendingNotifier,
      builder: (context, isIgnorePointer, child) {
        return IgnorePointer(ignoring: isIgnorePointer, child: child);
      },
      child: KeyboardDismissOnTap(
        child: Scaffold(
          backgroundColor: const Color(0xFF131314),
          appBar: AppBar(
            backgroundColor: const Color(0xFF131314).withOpacity(0.80),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: ChatViewStyle.appBarHeight(context),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Padding(
              padding: ChatViewStyle.paddingLeading(context),
              child: Row(
                children: [
                  DraftChatViewStyle.responsive.isMobile(context)
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          child: TwakeIconButton(
                            tooltip: L10n.of(context)!.back,
                            icon: Icons.arrow_back,
                            iconColor: Colors.white,
                            onTap: () => context.pop(),
                            paddingAll: 8.0,
                            margin: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        )
                      : const SizedBox.shrink(),
                  Expanded(
                    child: _EmptyChatTitle(
                      receiverId: controller.presentationContact.matrixId!,
                      displayName: controller.presentationContact.displayName,
                      onTap: controller.onPushDetails,
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size(double.infinity, 1),
              child: Container(
                color: Colors.white.withOpacity(0.10),
                height: 1,
              ),
            ),
          ),
          body:
              AndroidUtils.isNavigationButtonsEnabled(
                systemGestureInsets: MediaQuery.systemGestureInsetsOf(context),
              )
              ? SafeArea(child: _chatViewBody(context))
              : _chatViewBody(context),
        ),
      ),
    );
  }

  Widget _chatViewBody(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          const ChatBackground(),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: DropTarget(
                    onDragDone: (details) => controller.handleDragDone(details),
                    onDragEntered: controller.onDragEntered,
                    onDragExited: controller.onDragExited,
                    child: const DraftChatEmpty(),
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: controller.isBlockedUserNotifier,
                builder: (context, isBlocked, child) {
                  if (!isBlocked) {
                    return child ?? const SizedBox();
                  }

                  return const BlockedMessageView();
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF131314),
                    border: Border(
                      top: BorderSide(color: Color(0x0DFFFFFF)),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: DraftChatViewStyle.bottomBarInputPadding(context),
                  ),
                  child: DraftChatInputRow(
                    onEmojiAction: controller.onEmojiAction,
                    onInputBarChanged: controller.onInputBarChanged,
                    onInputBarSubmitted: controller.onInputBarSubmitted,
                    onSendFileClick: controller.onSendFileClick,
                    textEditingController: controller.sendController,
                    typeAheadFocusNode: controller.inputFocus,
                    typeAheadKey: controller.draftChatComposerTypeAheadKey,
                    focusSuggestionController:
                        controller.focusSuggestionController,
                    inputText: controller.inputText,
                    isSendingNotifier: controller.isSendingNotifier,
                    onLongPressAudioRecord:
                        controller.onLongPressAudioRecordInMobile,
                    audioRecordStateNotifier:
                        controller.audioRecordStateNotifier,
                    startRecording: () {
                      controller.startRecording();
                    },
                    stopRecording: () {
                      if (controller.sendController.text.isNotEmpty) {
                        controller.sendController.clear();
                      }
                      controller.stopRecording();
                    },
                    pauseRecording: () {
                      controller.pauseRecording();
                    },
                    deleteRecording: () {
                      controller.deleteRecording();
                    },
                    sendVoiceMessageAction: (audioFile, duration, waveform) =>
                        controller.sendVoiceMessageAction(
                          audioFile: audioFile,
                          time: duration,
                          waveform: waveform,
                        ),
                    onTapRecorderWeb: () =>
                        controller.onTapRecorderWeb(context: context),
                    onFinishRecorderWeb: controller.sendVoiceMessageWeb,
                    onDeleteRecorderWeb: controller.stopRecordWeb,
                    recordDurationWebNotifier:
                        controller.recordDurationWebNotifier,
                  ),
                ),
              ),
            ],
          ),
          ValueListenableBuilder(
            valueListenable: controller.showEmojiPickerComposerNotifier,
            builder: (context, display, _) {
              if (!display) return const SizedBox.shrink();
              return Positioned(
                bottom: 72,
                right: 64,
                child: MouseRegion(
                  onHover: (_) {
                    controller.showEmojiPickerComposerNotifier.value = true;
                  },
                  onExit: (_) async {
                    await Future.delayed(const Duration(seconds: 1));
                    controller.showEmojiPickerComposerNotifier.value = false;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: ChatController.defaultMaxWidthReactionPicker,
                    height: ChatController.defaultMaxHeightReactionPicker,
                    decoration: BoxDecoration(
                      color: LinagoraRefColors.material().primary[100],
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x0000004D).withOpacity(0.15),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(0x00000026).withOpacity(0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: EmojiPicker(
                      emojiData: Matrix.of(context).emojiData,
                      recentEmoji: controller.getRecentReactionsInteractor
                          .execute(),
                      configuration: EmojiPickerConfiguration(
                        showRecentTab: true,
                        emojiStyle: Theme.of(context).textTheme.headlineLarge!,
                        searchEmptyTextStyle: Theme.of(context)
                            .textTheme
                            .labelMedium!
                            .copyWith(
                              color: LinagoraRefColors.material().tertiary[30],
                            ),
                        searchEmptyWidget: SvgPicture.asset(
                          ImagePaths.icSearchEmojiEmpty,
                        ),
                        searchFocusNode: FocusNode(),
                      ),
                      itemBuilder: (context, emojiId, emoji, callback) {
                        return MouseRegion(
                          onHover: (_) {},
                          child: EmojiItem(
                            textStyle: Theme.of(
                              context,
                            ).textTheme.headlineLarge!,
                            onTap: () {
                              callback(emojiId, emoji);
                            },
                            emoji: emoji,
                          ),
                        );
                      },
                      onEmojiSelected: (emojiId, emoji) {
                        controller.typeEmoji(emoji);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: controller.isBlockedUserNotifier,
            builder: (context, isBlockedUser, _) {
              if (!isBlockedUser) return const SizedBox.shrink();
              return Column(
                children: [
                  TwakeInkWell(
                    onTap: () async => controller.onTapUnblockUser(
                      context: context,
                      client: Matrix.of(context).client,
                      displayName:
                          controller.presentationContact.matrixId ?? '',
                      userID: controller.presentationContact.matrixId ?? '',
                    ),
                    child: const BlockedUserBanner(),
                  ),
                  Divider(
                    height: ChatViewBodyStyle.dividerSize,
                    thickness: ChatViewBodyStyle.dividerSize,
                    color: Theme.of(context).dividerColor,
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: getIt.get<ContactsManager>().getContactsNotifier(),
            builder: (context, state, child) {
              if (controller.isInsideContactManager(state)) {
                return const SizedBox();
              }

              return child ?? const SizedBox();
            },
            child: AddContactBanner(
              onTap: () => showAddContactDialog(
                context,
                displayName: controller.widget.contact.displayName,
                matrixId: controller.widget.contact.matrixId,
              ),
              show: controller.showAddContactBanner,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatTitle extends StatefulWidget {
  const _EmptyChatTitle({
    required this.receiverId,
    this.displayName,
    this.onTap,
  });

  final String receiverId;

  final String? displayName;

  final VoidCallback? onTap;

  @override
  State<_EmptyChatTitle> createState() => _EmptyChatTitleState();
}

class _EmptyChatTitleState extends State<_EmptyChatTitle> {
  Profile? _profile;
  CachedPresence? _presence;
  StreamSubscription<CachedPresence>? _presenceSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProfile();
      _loadPresence();
      _listenPresence();
    });
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await Matrix.of(context).client.getProfileFromUserId(
        widget.receiverId,
        getFromRooms: false,
      );
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) {
        setState(
          () => _profile = Profile(
            avatarUrl: null,
            displayName: null,
            userId: widget.receiverId,
          ),
        );
      }
    }
  }

  Future<void> _loadPresence() async {
    final client = Matrix.of(context).client;
    final cached = client.presences[widget.receiverId];
    if (cached != null && mounted) {
      setState(() => _presence = cached);
    }
    try {
      final response = await client.getPresence(widget.receiverId);
      if (mounted) {
        setState(
          () => _presence = CachedPresence.fromPresenceResponse(
            response,
            widget.receiverId,
          ),
        );
      }
    } catch (_) {
      if (mounted && _presence == null) {
        setState(
          () => _presence = CachedPresence.neverSeen(widget.receiverId),
        );
      }
    }
  }

  void _listenPresence() {
    _presenceSub = Matrix.of(context).onLatestPresenceChanged.stream.listen((
      event,
    ) {
      if (event.userid == widget.receiverId && mounted) {
        setState(() => _presence = event);
      }
    });
  }

  String _localizedPresence(BuildContext context, CachedPresence? presence) {
    final l10n = L10n.of(context)!;
    if (presence == null) return l10n.loadingStatus;
    if (presence.presence == PresenceType.online) return l10n.online;
    final lastActive = presence.lastActiveTimestamp;
    if (lastActive != null) {
      final now = DateTime.now();
      if (lastActive.isLessThanOneMinuteAgo()) return l10n.online;
      if (lastActive.isLessThanOneHourAgo()) {
        return l10n.onlineMinAgo(now.difference(lastActive).inMinutes);
      }
      if (lastActive.isLessThanADayAgo()) {
        return l10n.onlineHourAgo(
          (now.difference(lastActive).inMinutes / 60).round(),
        );
      }
      if (lastActive.isLessThan30DaysAgo()) {
        return l10n.onlineDayAgo(now.difference(lastActive).inDays);
      }
      return l10n.aWhileAgo;
    }
    return l10n.offline;
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _profile?.displayName ?? widget.displayName ?? widget.receiverId;
    final status = _localizedPresence(context, _presence).toUpperCase();
    return InkWell(
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: widget.onTap,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Hero(
              tag: 'content_banner',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: Avatar(
                    fontSize: ChatAppBarTitleStyle.avatarFontSize,
                    mxContent: _profile?.avatarUrl,
                    name: name,
                    size: ChatAppBarTitleStyle.avatarSize(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.capitalize(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    letterSpacing: -0.3,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x99C6C6C6),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
