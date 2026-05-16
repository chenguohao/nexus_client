import 'package:fluffychat/presentation/extensions/room_summary_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/avatar/avatar_gradient_placeholder.dart';
import 'package:fluffychat/widgets/avatar/avatar_style.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Avatar for a [Room].
///
/// Display rules (see `docs/group-avatar.md` for the full spec):
///
/// 1. If the room has a custom avatar set, show it (single image).
/// 2. Otherwise, for a group chat (non direct chat), show a 2×2 grid
///    built from the first three members' avatars and a `+N` badge
///    in the bottom-right cell where `N = totalMembers - slotsUsed`.
/// 3. For a direct chat without an avatar, fall back to the classic
///    single-letter placeholder.
class RoomAvatar extends StatelessWidget {
  final Room room;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final double fontSize;
  final bool keepAlive;

  const RoomAvatar({
    super.key,
    required this.room,
    required this.name,
    this.size = AvatarStyle.defaultSize,
    this.onTap,
    this.fontSize = AvatarStyle.defaultFontSize,
    this.keepAlive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (room.avatar != null || room.isDirectChat) {
      return Avatar(
        mxContent: room.avatar,
        name: name,
        size: size,
        onTap: onTap,
        fontSize: fontSize,
        keepAlive: keepAlive,
      );
    }
    return _GroupGridAvatar(
      key: ValueKey('room_avatar_${room.id}'),
      room: room,
      size: size,
      onTap: onTap,
    );
  }
}

class _GroupGridAvatar extends StatefulWidget {
  final Room room;
  final double size;
  final VoidCallback? onTap;

  const _GroupGridAvatar({
    super.key,
    required this.room,
    required this.size,
    required this.onTap,
  });

  @override
  State<_GroupGridAvatar> createState() => _GroupGridAvatarState();
}

class _GroupGridAvatarState extends State<_GroupGridAvatar> {
  static const double _cornerRadius = 4.0;
  static const double _gap = 1.5;
  static const Color _borderColor = Color(0xFF474747);
  static const Color _cellBgColor = Color(0xFF2A2A2B);
  static const Color _countBgColor = Color(0xFF3A3A3A);

  /// Members we consider "part of the group" for the grid: both joined
  /// members and pending invites, matching what the group info page shows
  /// (via `room.summary.actualMembersCount`).
  static const List<Membership> _visibleMemberships = [
    Membership.join,
    Membership.invite,
  ];

  /// Room ids we already asked the SDK to fully populate the member list for.
  /// Matrix SDK caches the response, but this avoids firing the same
  /// network request from multiple RoomAvatar instances while one is in flight.
  static final Set<String> _requestedRoomIds = <String>{};

  @override
  void initState() {
    super.initState();
    _maybeRequestParticipants();
  }

  @override
  void didUpdateWidget(covariant _GroupGridAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _maybeRequestParticipants();
    }
  }

  /// Members are lazy-loaded by the Matrix SDK: without asking, only the
  /// current user and the room heroes are in local state, which produces
  /// incomplete grids for small groups (e.g. 2 avatars in a 3-member group).
  Future<void> _maybeRequestParticipants() async {
    final room = widget.room;
    final total = room.summary.actualMembersCount;
    final cached = room.getParticipants(_visibleMemberships).length;
    if (total <= cached) return;
    if (_requestedRoomIds.contains(room.id)) return;
    _requestedRoomIds.add(room.id);
    try {
      await room.requestParticipants(_visibleMemberships, false, true);
      if (mounted) setState(() {});
    } catch (e, s) {
      Logs().w('RoomAvatar: failed to request participants for ${room.id}', e, s);
      _requestedRoomIds.remove(room.id);
    }
  }

  /// Pick up to three members to display, in a stable order:
  /// creator first, then the rest sorted by power level (desc) and
  /// matrix id (asc) as a tiebreaker so the same group always produces
  /// the same grid.
  List<User> _pickTopMembers() {
    final participants =
        widget.room.getParticipants(_visibleMemberships).toList()
          ..sort((a, b) {
            final byPower = b.powerLevel.compareTo(a.powerLevel);
            if (byPower != 0) return byPower;
            return a.id.compareTo(b.id);
          });
    final creatorId = widget.room.getState(EventTypes.RoomCreate)?.senderId;
    if (creatorId != null && creatorId.isNotEmpty) {
      final idx = participants.indexWhere((u) => u.id == creatorId);
      if (idx > 0) {
        final creator = participants.removeAt(idx);
        participants.insert(0, creator);
      }
    }
    return participants.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final members = _pickTopMembers();
    // `actualMembersCount` sums joined + invited and is the value already
    // used elsewhere (e.g. chat details subtitle), so it is the most stable
    // source of truth for the total headcount.
    final totalCount = widget.room.summary.actualMembersCount;
    // Only show the `+N` badge when there are members beyond the 3 we can
    // render as avatars. For groups with <= 3 members everyone fits in the
    // first three cells, so the bottom-right cell stays empty.
    final extra = totalCount > members.length ? totalCount - members.length : 0;
    final cellSize = (widget.size - _gap) / 2;

    Widget cell(int index) {
      if (index < members.length) {
        final user = members[index];
        return _MemberCell(
          client: widget.room.client,
          user: user,
          size: cellSize,
        );
      }
      if (index == 3 && extra > 0) {
        return _CountCell(count: extra, size: cellSize);
      }
      return const _EmptyCell();
    }

    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cornerRadius),
            border: Border.all(color: _borderColor, width: 1),
            color: _cellBgColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cornerRadius),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: cell(0)),
                      const SizedBox(width: _gap),
                      Expanded(child: cell(1)),
                    ],
                  ),
                ),
                const SizedBox(height: _gap),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: cell(2)),
                      const SizedBox(width: _gap),
                      Expanded(child: cell(3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberCell extends StatefulWidget {
  final Client client;
  final User user;
  final double size;

  const _MemberCell({
    required this.client,
    required this.user,
    required this.size,
  });

  @override
  State<_MemberCell> createState() => _MemberCellState();
}

class _MemberCellState extends State<_MemberCell> {
  Future<Profile?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MemberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _profileFuture = _loadProfileIfNeeded();
    }
  }

  /// 与聊天列表 DM 一致：成员事件里常常不带 avatar_url，需拉 Profile 才有 mxc。
  Future<Profile?>? _loadProfileIfNeeded() {
    if (widget.user.avatarUrl != null) return null;
    return widget.client.getProfileFromUserId(
      widget.user.id,
      getFromRooms: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.calcDisplayname();
    final Widget fallback = AvatarGradientPlaceholder(
      name: name,
      width: widget.size,
      height: widget.size,
      fontSize: widget.size * 0.42,
    );

    final directUri = widget.user.avatarUrl;
    if (directUri != null) {
      return _avatarImage(context, directUri, fallback);
    }

    final fut = _profileFuture;
    if (fut == null) {
      return fallback;
    }

    return FutureBuilder<Profile?>(
      future: fut,
      builder: (context, snapshot) {
        final uri = snapshot.data?.avatarUrl ?? directUri;
        if (uri == null) {
          return fallback;
        }
        return _avatarImage(context, uri, fallback);
      },
    );
  }

  Widget _avatarImage(
    BuildContext context,
    Uri mxContent,
    Widget fallback,
  ) {
    return MxcImage(
      key: Key(mxContent.toString()),
      uri: mxContent,
      fit: BoxFit.cover,
      width: widget.size,
      height: widget.size,
      cacheWidth:
          (widget.size * MediaQuery.devicePixelRatioOf(context) * 2).round(),
      cacheKey: mxContent.toString(),
      animated: true,
      isThumbnail: true,
      placeholder: (context) => fallback,
    );
  }
}

class _CountCell extends StatelessWidget {
  final int count;
  final double size;

  const _CountCell({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    // Always render with a leading `+` so the badge never gets confused with
    // a member initial placeholder (e.g. a user whose name starts with a
    // digit). 100+ collapses to `99+` to keep the cell readable.
    final text = count >= 100 ? '99+' : '+$count';
    // Shrink the font when we have 3 characters (e.g. `+12`, `99+`) so the
    // number still fits comfortably.
    final fontScale = text.length >= 3 ? 0.3 : 0.36;
    return Container(
      color: _GroupGridAvatarState._countBgColor,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size * fontScale,
          color: Colors.white,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return Container(color: _GroupGridAvatarState._cellBgColor);
  }
}
