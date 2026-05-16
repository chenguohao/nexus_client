import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/pages/contacts_tab/outgoing_requests/outgoing_requests_page.dart';
import 'package:fluffychat/zeon/services/friend_request_history.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 通讯录顶部"发出的请求"入口。
///
/// 显示规则：
/// - 当存在"我主动发起且未确认"的请求（pending_outgoing 或 rejected）时显示；
/// - 当本地历史里有 mxid 而对方已经 accepted（这种"已确认"也算我发起的）时也显示；
/// - 完全没有任何记录时整行隐藏。
class OutgoingRequestsEntry extends StatelessWidget {
  const OutgoingRequestsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = getIt.get<ContactsManager>();
    return ValueListenableBuilder(
      valueListenable: manager.getContactsNotifier(),
      builder: (context, state, _) {
        final success = state.getSuccessOrNull<GetContactsSuccess>();
        if (success == null) {
          return const SizedBox.shrink();
        }

        final history = FriendRequestHistoryStore.instance.snapshot;
        int pending = 0;
        int rejected = 0;
        int confirmed = 0;
        success.friendStatusByMxid.forEach((mxid, status) {
          switch (status) {
            case FriendStatus.pendingOutgoing:
              pending += 1;
              break;
            case FriendStatus.rejected:
              rejected += 1;
              break;
            case FriendStatus.accepted:
              if (history.contains(mxid)) confirmed += 1;
              break;
            case FriendStatus.pendingIncoming:
              break;
          }
        });
        final total = pending + rejected + confirmed;
        if (total == 0) return const SizedBox.shrink();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const OutgoingRequestsPage(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B1C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1F474747)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.outgoing_mail,
                    size: 20,
                    color: Color(0xFFE5E2E3),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '发出的请求',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFE5E2E3),
                      ),
                    ),
                  ),
                  if (pending > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '$pending',
                        style: const TextStyle(
                          color: ZeonColors.outline,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF919191),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
