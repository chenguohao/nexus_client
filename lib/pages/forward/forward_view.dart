import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/app_state/forward/forward_message_state.dart';
import 'package:fluffychat/pages/forward/forward.dart';
import 'package:fluffychat/pages/forward/recent_chat_list.dart';
import 'package:fluffychat/pages/forward/recent_chat_title.dart';
import 'package:fluffychat/pages/forward/forward_view_style.dart';
import 'package:fluffychat/widgets/app_bars/searchable_app_bar.dart';
import 'package:fluffychat/widgets/twake_components/twake_text_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ForwardView extends StatelessWidget {
  final ForwardController controller;

  const ForwardView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: PreferredSize(
        preferredSize: controller.isFullScreen
            ? ForwardViewStyle.preferredSize(context)
            : ForwardViewStyle.maxPreferredSize(context),
        child: ValueListenableBuilder<Either<Failure, Success>?>(
          valueListenable: controller.forwardMessageNotifier,
          builder: (context, forwardMessageState, child) {
            return SearchableAppBar(
              toolbarHeight: ForwardViewStyle.maxToolbarHeight(context),
              focusNode: controller.searchFocusNode,
              title: L10n.of(context)!.forwardTo,
              searchModeNotifier: controller.isSearchModeNotifier,
              hintText: L10n.of(context)!.searchContacts,
              textEditingController: controller.searchTextEditingController,
              openSearchBar: controller.openSearchBar,
              closeSearchBar: controller.closeSearchBar,
              isFullScreen: controller.isFullScreen,
              displayBackButton: forwardMessageState == null,
              backgroundColor: const Color(0xFF131314),
              foregroundColor: const Color(0xFFE5E2E3),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(
                ForwardViewStyle.paddingBody,
              ),
              child: Column(
                children: [
                  const RecentChatsTitle(),
                  ValueListenableBuilder<List<Room>>(
                    valueListenable: controller.recentlyChatsNotifier,
                    builder: (context, rooms, child) {
                      if (rooms.isNotEmpty) {
                        return RecentChatList(
                          rooms: rooms,
                          selectedChatNotifier:
                              controller.selectedRoomIdNotifier,
                          onSelectedChat: (roomId) =>
                              controller.onToggleSelectChat(roomId),
                          recentChatScrollController:
                              controller.recentChatScrollController,
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!controller.isFullScreen)
            _WebActionsButton(
              selectedChatNotifier: controller.selectedRoomIdNotifier,
              forwardMessageNotifier: controller.forwardMessageNotifier,
              forwardAction: controller.forwardAction,
            ),
        ],
      ),
      floatingActionButton: controller.isFullScreen
          ? _ForwardButton(
              forwardAction: controller.forwardAction,
              selectedChatNotifier: controller.selectedRoomIdNotifier,
              forwardMessageNotifier: controller.forwardMessageNotifier,
            )
          : null,
    );
  }
}

class _WebActionsButton extends StatelessWidget {
  final ValueNotifier<String> selectedChatNotifier;

  final ValueNotifier<Either<Failure, Success>?> forwardMessageNotifier;

  final void Function() forwardAction;

  const _WebActionsButton({
    required this.selectedChatNotifier,
    required this.forwardMessageNotifier,
    required this.forwardAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ForwardViewStyle.webActionsButtonPadding,
      child: ValueListenableBuilder<String>(
        valueListenable: selectedChatNotifier,
        builder: ((context, selectedChat, child) {
          return ValueListenableBuilder<Either<Failure, Success>?>(
            valueListenable: forwardMessageNotifier,
            builder: (context, forwardMessageState, child) {
              if (forwardMessageState == null) {
                return child!;
              } else {
                return forwardMessageState.fold((failure) => child!, (success) {
                  if (success is ForwardMessageLoading) {
                    return SizedBox(
                      height: ForwardViewStyle.bottomBarHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2B),
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0x33474747)),
                            ),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CupertinoActivityIndicator(
                                color: Color(0xFFE5E2E3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox();
                  }
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TwakeTextButton(
                  onTap: () => Navigator.of(context).pop(),
                  message: L10n.of(context)!.cancel,
                  borderHover: ForwardViewStyle.webActionsButtonBorder,
                  margin: ForwardViewStyle.webActionsButtonMargin,
                  buttonDecoration: BoxDecoration(
                    border: Border.all(color: const Color(0x33474747)),
                  ),
                  styleMessage: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: const Color(0xFF919191)),
                ),
                const SizedBox(width: 8.0),
                TwakeTextButton(
                  onTap: forwardAction,
                  message: L10n.of(context)!.add,
                  margin: ForwardViewStyle.webActionsButtonMargin,
                  borderHover: ForwardViewStyle.webActionsButtonBorder,
                  buttonDecoration: BoxDecoration(
                    color: selectedChat.isNotEmpty
                        ? const Color(0xFF2A2A2B)
                        : const Color(0xFF1C1B1C),
                    border: Border.all(color: const Color(0x33474747)),
                  ),
                  styleMessage: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(
                        color: selectedChat.isNotEmpty
                            ? const Color(0xFFE5E2E3)
                            : const Color(0xFF636363),
                      ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ForwardButton extends StatelessWidget {
  const _ForwardButton({
    required this.selectedChatNotifier,
    required this.forwardMessageNotifier,
    required this.forwardAction,
  });

  final ValueNotifier<String> selectedChatNotifier;

  final void Function() forwardAction;

  final ValueNotifier<Either<Failure, Success>?> forwardMessageNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedChatNotifier,
      builder: ((context, selectedChat, child) {
        if (selectedChat.isEmpty) {
          return const SizedBox();
        }

        return child!;
      }),
      child: ValueListenableBuilder<Either<Failure, Success>?>(
        valueListenable: forwardMessageNotifier,
        builder: (context, forwardMessageState, child) {
          if (forwardMessageState == null) {
            return child!;
          } else {
            return forwardMessageState.fold((failure) => child!, (success) {
              if (success is ForwardMessageLoading) {
                return SizedBox(
                  height: ForwardViewStyle.bottomBarHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2A2A2B),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x33474747)),
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(
                              color: Color(0xFFE5E2E3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox();
              }
            });
          }
        },
        child: SizedBox(
          height: ForwardViewStyle.bottomBarHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: InkWell(
                onTap: forwardAction,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2B),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x33474747)),
                    ),
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Color(0xFFE5E2E3),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
