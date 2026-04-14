import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/chat_list_header_style.dart';
import 'package:fluffychat/pages/search/search.dart';
import 'package:fluffychat/presentation/enum/chat_list/chat_list_enum.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/context_menu_builder_ios_paste_without_permission.dart';
import 'package:fluffychat/widgets/swipe_to_dismiss_wrap.dart';
import 'package:fluffychat/widgets/twake_components/twake_header.dart';
import 'package:flutter/material.dart';

class ChatListHeader extends StatelessWidget {
  final ChatListController controller;
  final VoidCallback? onOpenSearchPageInMultipleColumns;

  const ChatListHeader({
    super.key,
    required this.controller,
    this.onOpenSearchPageInMultipleColumns,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.selectModeNotifier,
      builder: (context, selectMode, _) {
        if (selectMode != SelectMode.normal) {
          return TwakeHeader(
            onClearSelection: controller.onClickClearSelection,
            client: controller.activeClient,
            selectModeNotifier: controller.selectModeNotifier,
            conversationSelectionNotifier:
                controller.conversationSelectionNotifier,
            onClickAvatar: controller.onClickAvatar,
          );
        }
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                color: const Color(0xFF131314),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: PlatformInfos.isWeb
                    ? _normalModeWidgetWeb(context)
                    : _normalModeWidgetsMobile(context),
              ),
              _buildFilterChips(),
              // if (PlatformInfos.isMobile)
                // ChatAudioPlayerWidget(matrix: controller.matrixState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Container();
    return Container(
      color: const Color(0xFF131314),
      height: 44,
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(label: 'ALL CHATS', isSelected: true, onTap: () {}),
          _FilterChip(label: 'GROUPS', isSelected: false, onTap: () {}),
          _FilterChip(label: 'UNREAD', isSelected: false, onTap: () {}),
          _FilterChip(label: 'ARCHIVE', isSelected: false, onTap: () {}),
        ],
      ),
    );
  }

  Widget _normalModeWidgetsMobile(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateWithSlideAnimation(context),
            child: TextField(
              textInputAction: TextInputAction.search,
              enabled: false,
              decoration: ChatListHeaderStyle.searchInputDecoration(context),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateWithSlideAnimation(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SwipeToDismissWrap(child: Search());
        },
      ),
    );
  }

  Widget _normalModeWidgetWeb(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(
              ChatListHeaderStyle.searchRadiusBorder,
            ),
            onTap: onOpenSearchPageInMultipleColumns,
            child: ValueListenableBuilder(
              valueListenable: controller.matrixState.showToMBootstrap,
              builder: (context, value, _) {
                return TextField(
                  textInputAction: TextInputAction.search,
                  contextMenuBuilder: mobileTwakeContextMenuBuilder,
                  enabled: false,
                  decoration: ChatListHeaderStyle.searchInputDecoration(
                    context,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontFamily: 'Inter',
              color: isSelected ? Colors.white : const Color(0xFFC6C6C6),
            ),
          ),
        ),
      ),
    );
  }
}
