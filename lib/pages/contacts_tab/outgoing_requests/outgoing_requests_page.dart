import 'package:collection/collection.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:fluffychat/zeon/pages/contact_preview/zeon_contact_preview_page.dart';
import 'package:fluffychat/zeon/services/friend_request_history.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

/// 「发出的请求」二级页：按服务端最后更新时间倒序平铺；
/// 每条展示昵称/Matrix ID、当前状态与最后更新时间。
class OutgoingRequestsPage extends StatefulWidget {
  const OutgoingRequestsPage({super.key});

  @override
  State<OutgoingRequestsPage> createState() => _OutgoingRequestsPageState();
}

class _OutgoingRequestsPageState extends State<OutgoingRequestsPage> {
  ContactsManager get _manager => getIt.get<ContactsManager>();

  /// 全局 [ContactsManager] 在别处触发刷新时会先发 [ContactsLoading]，快照短暂丢失。
  /// 本页保留最近一次成功结果，避免列表与转圈交替闪烁。
  String? _stickySnapshotOwnerUserId;
  GetContactsSuccess? _stickyContactsSuccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _manager.refreshTomContacts(Matrix.of(context).client, silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: TwakeAppBar(
        context: context,
        title: '发出的请求',
        backgroundColor: const Color(0xFF131314),
        withDivider: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _manager.getContactsNotifier(),
        builder: (context, state, _) {
          final matrixClientUserId = Matrix.of(context).client.userID;
          if (_stickySnapshotOwnerUserId != matrixClientUserId) {
            _stickySnapshotOwnerUserId = matrixClientUserId;
            _stickyContactsSuccess = null;
          }

          final ok = state.getSuccessOrNull<GetContactsSuccess>();
          if (ok != null) {
            _stickyContactsSuccess = ok;
          }

          final displaySuccess = ok ?? _stickyContactsSuccess;
          if (displaySuccess == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE5E2E3)),
            );
          }

          final history = FriendRequestHistoryStore.instance.snapshot;
          final rows = <_OutgoingRow>[];

          for (final c in displaySuccess.contacts) {
            final mxid = c.emails
                ?.where(
                  (e) => e.matrixId != null && e.matrixId!.isNotEmpty,
                )
                .map((e) => e.matrixId!)
                .firstOrNull;
            if (mxid == null || mxid.isEmpty) continue;

            switch (c.friendStatus) {
              case FriendStatus.pendingOutgoing:
                rows.add(
                  _OutgoingRow(
                    mxid: mxid,
                    displayName: c.displayName ?? mxid,
                    statusLabel: _OutgoingRow.labelPending,
                    updatedAtMillis: c.updatedAtMillis,
                  ),
                );
                break;
              case FriendStatus.rejected:
                rows.add(
                  _OutgoingRow(
                    mxid: mxid,
                    displayName: c.displayName ?? mxid,
                    statusLabel: _OutgoingRow.labelRejected,
                    updatedAtMillis: c.updatedAtMillis,
                  ),
                );
                break;
              case FriendStatus.accepted:
                if (history.contains(mxid)) {
                  rows.add(
                    _OutgoingRow(
                      mxid: mxid,
                      displayName: c.displayName ?? mxid,
                      statusLabel: _OutgoingRow.labelAccepted,
                      updatedAtMillis: c.updatedAtMillis,
                    ),
                  );
                }
                break;
              case FriendStatus.pendingIncoming:
                break;
            }
          }

          rows.sort((a, b) {
            final ta = a.updatedAtMillis ?? 0;
            final tb = b.updatedAtMillis ?? 0;
            if (ta != tb) return tb.compareTo(ta);
            return a.mxid.compareTo(b.mxid);
          });

          if (rows.isEmpty) {
            return const Center(
              child: Text(
                '暂无发出的请求',
                style: TextStyle(color: Color(0xFF919191), fontSize: 14),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _OutgoingTile(
              row: rows[i],
              localeName: Localizations.localeOf(context).toString(),
              matrixClient: Matrix.of(context).client,
            ),
          );
        },
      ),
    );
  }
}

class _OutgoingRow {
  static const labelPending = '待确认';
  static const labelAccepted = '已同意';
  static const labelRejected = '已拒绝';

  final String mxid;
  final String displayName;
  final String statusLabel;
  final int? updatedAtMillis;

  _OutgoingRow({
    required this.mxid,
    required this.displayName,
    required this.statusLabel,
    required this.updatedAtMillis,
  });
}

class _OutgoingTile extends StatelessWidget {
  final _OutgoingRow row;
  final String localeName;
  final Client matrixClient;

  const _OutgoingTile({
    required this.row,
    required this.localeName,
    required this.matrixClient,
  });

  String _formatTime() {
    final millis = row.updatedAtMillis;
    if (millis == null || millis <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) {
      return DateFormat.Hm(localeName).format(dt);
    }
    return DateFormat('MM/dd HH:mm', localeName).format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final initial = row.displayName.isNotEmpty
        ? row.displayName[0].toUpperCase()
        : '?';

    final pending = row.statusLabel == _OutgoingRow.labelPending;

    final tile = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1C),
        border: Border.all(color: const Color(0x33474747)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              color: const Color(0xFF2A2A2B),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFFE5E2E3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: const TextStyle(
                    color: Color(0xFFE5E2E3),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.mxid,
                  style: const TextStyle(
                    color: Color(0xFF636363),
                    fontSize: 12,
                    letterSpacing: 0.25,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.statusLabel,
                style: const TextStyle(
                  color: Color(0xFFE5E2E3),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(),
                style: const TextStyle(
                  color: Color(0xFF919191),
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!pending) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ZeonContactPreviewPage(
                mxid: row.mxid,
                initialDisplayName: row.displayName,
                awaitingRecipientConfirmation: true,
                matrixClient: matrixClient,
              ),
            ),
          );
        },
        child: tile,
      ),
    );
  }
}
