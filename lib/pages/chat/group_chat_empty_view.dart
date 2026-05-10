import 'package:fluffychat/pages/chat/group_chat_empty_view_style.dart';
import 'package:fluffychat/pages/chat/others_group_chat_empty_view.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class GroupChatEmptyView extends StatelessWidget {
  final Event firstEvent;

  const GroupChatEmptyView({super.key, required this.firstEvent});

  @override
  Widget build(BuildContext context) {
    final hasCreatedRoom =
        firstEvent.type == EventTypes.RoomCreate &&
        firstEvent.senderId == Matrix.of(context).client.userID;

    return hasCreatedRoom
        ? _buildOwnGroupChatEmptyView(context)
        : OthersGroupChatEmptyView(firstEvent: firstEvent);
  }

  Widget _buildOwnGroupChatEmptyView(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: GroupChatEmptyViewStyle.maxWidth(context),
        minWidth: GroupChatEmptyViewStyle.minWidth,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33474747)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFFE5E2E3),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'GROUP CREATED',
                style: GroupChatEmptyViewStyle.titleStyle(context),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: const Color(0x1F474747)),
          const SizedBox(height: 20),
          // Feature rows
          _featureRow(context, 'Up to 10,000 members'),
          const SizedBox(height: 12),
          _featureRow(context, 'End-to-end encryption enabled'),
        ],
      ),
    );
  }

  Widget _featureRow(BuildContext context, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check,
            size: 14,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GroupChatEmptyViewStyle.ruleStyle(context),
          ),
        ),
      ],
    );
  }
}
