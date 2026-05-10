import 'package:fluffychat/presentation/model/chat/chat_details/chat_details_group_action.dart';
import 'package:fluffychat/presentation/model/chat/chat_details/chat_details_message_action.dart';
import 'package:fluffychat/presentation/model/chat/chat_details/chat_details_mute_action.dart';
import 'package:fluffychat/presentation/model/chat/chat_details/chat_details_search_action.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatDetailsGroupActionsView extends StatelessWidget {
  const ChatDetailsGroupActionsView({
    super.key,
    required this.onMessage,
    required this.onSearch,
    this.onToggleNotification,
    this.muteNotifier,
    required this.animationController,
  });

  final VoidCallback onMessage;
  final VoidCallback onSearch;
  final VoidCallback? onToggleNotification;
  final ValueNotifier<PushRuleState>? muteNotifier;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (muteNotifier == null) {
      return _buildActions(context, textTheme, [
        ChatDetailsMessageAction(onMessage: onMessage),
        ChatDetailsSearchAction(onSearch: onSearch),
      ]);
    }

    return ValueListenableBuilder(
      valueListenable: muteNotifier!,
      builder: (context, value, child) {
        final actions = [
          ChatDetailsMessageAction(onMessage: onMessage),
          ChatDetailsMuteAction(
            onMute: onToggleNotification ?? () {},
            isMute: value != PushRuleState.notify,
          ),
          ChatDetailsSearchAction(onSearch: onSearch),
        ];

        return _buildActions(context, textTheme, actions);
      },
    );
  }

  Widget _buildActions(
    BuildContext context,
    TextTheme textTheme,
    List<ChatDetailsGroupAction> actions,
  ) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        8,
        12,
        Tween<double>(begin: 0, end: 16).transform(animationController.value),
      ),
      child: Row(
        children: List.generate(actions.length, (index) {
          final padding = EdgeInsetsDirectional.only(
            start: index == 0 ? 0 : 12,
          );
          return Expanded(
            child: Padding(
              padding: padding,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: actions[index].onTap,
                  onTapDown: (details) =>
                      actions[index].onTapDown?.call(context, details),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsetsDirectional.fromSTEB(9, 10, 9, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B1C),
                      border: Border.all(color: const Color(0x33474747)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          actions[index].icon,
                          size: 22,
                          color: const Color(0xFFE5E2E3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          actions[index].getTitle(context),
                          style: textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF919191),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
