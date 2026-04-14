import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/presentation/decorators/chat_list/subtitle_text_style_decorator/subtitle_text_style_component.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

abstract class ChatListSubtitleTextStyleDecorator
    implements ChatListSubtitleTextStyleComponent {
  final ChatListSubtitleTextStyleComponent interfaceTextStyleComponent;

  ChatListSubtitleTextStyleDecorator(this.interfaceTextStyleComponent);
}

class ChatListSubtitleTextStyle implements ChatListSubtitleTextStyleDecorator {
  final ChatListSubtitleTextStyleComponent _interfaceTextStyleComponent;

  ChatListSubtitleTextStyle(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room, BuildContext context) {
    return _interfaceTextStyleComponent.textStyle(room, context);
  }

  @override
  ChatListSubtitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}

class ReadChatListSubtitleTextStyleDecorator
    implements ChatListSubtitleTextStyleComponent {
  @override
  TextStyle textStyle(Room room, BuildContext context) {
    return const TextStyle(
      color: Color(0xFFC6C6C6),
      fontSize: 14,
      fontFamily: 'Inter',
    );
  }
}

class UnreadChatListSubtitleTextStyleDecorator
    implements ChatListSubtitleTextStyleDecorator {
  final ChatListSubtitleTextStyleComponent _interfaceTextStyleComponent;

  UnreadChatListSubtitleTextStyleDecorator(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room, BuildContext context) {
    if (room.isUnreadOrInvited) {
      return _interfaceTextStyleComponent
          .textStyle(room, context)
          .copyWith(color: Colors.white);
    } else {
      return _interfaceTextStyleComponent.textStyle(room, context);
    }
  }

  @override
  ChatListSubtitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}

class MuteChatListSubtitleTextStyleDecorator
    implements ChatListSubtitleTextStyleDecorator {
  final ChatListSubtitleTextStyleComponent _interfaceTextStyleComponent;

  MuteChatListSubtitleTextStyleDecorator(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room, BuildContext context) {
    if (room.isMuted) {
      return _interfaceTextStyleComponent
          .textStyle(room, context)
          .copyWith(color: const Color(0xFF919191));
    } else {
      return _interfaceTextStyleComponent.textStyle(room, context);
    }
  }

  @override
  ChatListSubtitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}
