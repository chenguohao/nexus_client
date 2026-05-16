/// 好友关系状态。对应服务端 zeon_server 的 contacts.status 字段。
///
/// 说明：
/// - [accepted]：双方好友。可发消息、互拉群。
/// - [pendingOutgoing]：我发出的好友请求，等对方处理。本机本端可见，
///   不显示对方真头像/真昵称，禁止再次操作。
/// - [pendingIncoming]：对方发来的好友请求，等我处理。同步表现为收到
///   一条 DM 邀请，复用 [chat_invitation_body] 接受/拒绝即可。
/// - [rejected]：我发出的请求被对方拒绝。对方端没有这条记录，仅在我端保留
///   作为历史，可重新发起申请。
enum FriendStatus {
  accepted,
  pendingOutgoing,
  pendingIncoming,
  rejected;

  static FriendStatus fromString(String? raw) {
    switch (raw) {
      case 'pending_outgoing':
        return FriendStatus.pendingOutgoing;
      case 'pending_incoming':
        return FriendStatus.pendingIncoming;
      case 'rejected':
        return FriendStatus.rejected;
      case 'accepted':
      default:
        // 旧客户端 / 旧记录默认 accepted。
        return FriendStatus.accepted;
    }
  }

  String get rawValue {
    switch (this) {
      case FriendStatus.accepted:
        return 'accepted';
      case FriendStatus.pendingOutgoing:
        return 'pending_outgoing';
      case FriendStatus.pendingIncoming:
        return 'pending_incoming';
      case FriendStatus.rejected:
        return 'rejected';
    }
  }

  bool get isAccepted => this == FriendStatus.accepted;

  bool get isPending =>
      this == FriendStatus.pendingOutgoing ||
      this == FriendStatus.pendingIncoming;
}
