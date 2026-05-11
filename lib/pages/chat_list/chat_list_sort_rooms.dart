import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatListSortRooms extends StatefulWidget {
  const ChatListSortRooms({
    super.key,
    required this.rooms,
    required this.builder,
    required this.sortingRoomsNotifier,
  });

  final List<Room> rooms;
  final Widget Function(
    List<Room> sortedRooms,
    Map<String, Event?> lastEventByRoomId,
  )
  builder;
  final ValueNotifier<bool> sortingRoomsNotifier;

  @override
  State<ChatListSortRooms> createState() => _ChatListSortRoomsState();
}

class _ChatListSortRoomsState extends State<ChatListSortRooms> {
  Map<String, Event?> _lastEventByRoomId = {};
  List<Room> _sortCache = [];
  Map<String, StreamSubscription?> _roomSubscriptions = {};

  RoomSorter sortRoomsBy(Client client) => (a, b) {
    if (client.pinInvitedRooms &&
        a.membership != b.membership &&
        [a.membership, b.membership].any((m) => m == Membership.invite)) {
      return a.membership == Membership.invite ? -1 : 1;
    }
    if (a.isFavourite != b.isFavourite) {
      return a.isFavourite ? -1 : 1;
    }
    if (client.pinUnreadRooms && a.notificationCount != b.notificationCount) {
      return b.notificationCount.compareTo(a.notificationCount);
    }
    return (_lastEventByRoomId[b.id]?.originServerTs ??
            b.latestEventReceivedTime)
        .millisecondsSinceEpoch
        .compareTo(
          (_lastEventByRoomId[a.id]?.originServerTs ??
                  a.latestEventReceivedTime)
              .millisecondsSinceEpoch,
        );
  };

  Future<List<Room>> sortRooms() async {
    await Matrix.of(context).initSettingsCompleter.future;
    for (final room in widget.rooms) {
      if (_lastEventByRoomId[room.id] != null) continue;

      // Query the database for the last preview event.
      final dbEvent = await room.lastEventAvailableInPreview();

      // The database query may lag behind in-memory state: newly sent
      // local-echo events (sending / sent) are not yet persisted when this
      // runs.  Prefer room.lastEvent if it is more recent so that the chat
      // list always reflects the most recently sent message immediately.
      final memEvent = room.lastEvent;
      Event? chosen = dbEvent;
      if (memEvent != null) {
        if (dbEvent == null ||
            memEvent.originServerTs.isAfter(dbEvent.originServerTs)) {
          chosen = memEvent;
        }
      }

      _lastEventByRoomId[room.id] = chosen;
    }
    widget.sortingRoomsNotifier.value = false;
    return List.from(widget.rooms)
      ..sort(sortRoomsBy(Matrix.of(context).client));
  }

  @override
  void initState() {
    super.initState();
    _lastEventByRoomId = Map.fromEntries(
      widget.rooms.map((room) => MapEntry(room.id, null)),
    );
    _roomSubscriptions = Map.fromEntries(
      widget.rooms.map(
        (room) => MapEntry(
          room.id,
          room.onUpdate.stream.listen((roomId) {
            if (mounted) {
              setState(() {
                _lastEventByRoomId[roomId] = null;
              });
            }
          }),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ChatListSortRooms oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastEventByRoomId = Map.fromEntries(
      widget.rooms.map(
        (room) => MapEntry(
          room.id,
          _lastEventByRoomId.putIfAbsent(room.id, () => null),
        ),
      ),
    );
    final removedRooms = oldWidget.rooms
        .whereNot(widget.rooms.contains)
        .toList();
    for (final room in removedRooms) {
      _roomSubscriptions[room.id]?.cancel();
    }
    _roomSubscriptions = Map.fromEntries(
      widget.rooms.map(
        (room) => MapEntry(
          room.id,
          _roomSubscriptions.putIfAbsent(
            room.id,
            () => room.onUpdate.stream.listen((roomId) {
              if (mounted) {
                setState(() {
                  _lastEventByRoomId[roomId] = null;
                });
              }
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sortRooms(),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          _sortCache = snapshot.data!;
        }

        return widget.builder(
          _sortCache.isEmpty ? widget.rooms : _sortCache,
          _lastEventByRoomId,
        );
      },
    );
  }
}
