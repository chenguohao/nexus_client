import 'package:fluffychat/utils/matrix_sdk_extensions/client_stories_extension.dart';
import 'package:fluffychat/widgets/twake_components/twake_navigation_icon/twake_navigation_icon.dart';
import 'package:fluffychat/widgets/unread_rooms_badge.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

enum AdaptiveDestinationEnum {
  rooms,
  contacts,
  settings;

  NavigationDestination getNavigationDestination(
    BuildContext context,
    ValueNotifier<Profile?> profile,
  ) {
    switch (this) {
      case AdaptiveDestinationEnum.rooms:
        return NavigationDestination(
          key: const Key('rooms_navigation_destination'),
          icon: UnreadRoomsBadge(
            color: const Color(0xFFC6C6C6),
            filter: (room) => !room.isSpace && !room.isStoryRoom,
          ),
          selectedIcon: UnreadRoomsBadge(
            filter: (room) => !room.isSpace && !room.isStoryRoom,
            isSelected: true,
          ),
          label: 'MESSAGES',
        );
      case AdaptiveDestinationEnum.contacts:
        return const NavigationDestination(
          key: Key('contacts_navigation_destination'),
          icon: TwakeNavigationIcon(
            color: Color(0xFFC6C6C6),
            icon: Icons.group_outlined,
          ),
          label: 'CONTACTS',
          selectedIcon: TwakeNavigationIcon(
            icon: Icons.group,
            isSelected: true,
          ),
        );
      case AdaptiveDestinationEnum.settings:
        // Despite the enum name being "settings" for backwards compatibility,
        // this destination now renders the Zeon Profile page (Sovereign style)
        // which contains the Settings shortcut as one of its list items.
        return const NavigationDestination(
          key: Key('profile_navigation_destination'),
          icon: TwakeNavigationIcon(
            color: Color(0xFFC6C6C6),
            icon: Icons.person_outline,
          ),
          selectedIcon: TwakeNavigationIcon(
            icon: Icons.person,
            isSelected: true,
          ),
          label: 'PROFILE',
        );
    }
  }

  BottomNavigationBarItem getNavigationDestinationForBottomBar(
    BuildContext context,
    ValueNotifier<Profile?> profile,
  ) {
    switch (this) {
      case AdaptiveDestinationEnum.rooms:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline, color: Color(0xFF919191)),
          activeIcon: Icon(Icons.chat_bubble, color: Colors.white),
          label: 'MESSAGES',
        );
      case AdaptiveDestinationEnum.contacts:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.group_outlined, color: Color(0xFF919191)),
          activeIcon: Icon(Icons.group, color: Colors.white),
          label: 'CONTACTS',
        );
      case AdaptiveDestinationEnum.settings:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, color: Color(0xFF919191)),
          activeIcon: Icon(Icons.person, color: Colors.white),
          label: 'PROFILE',
        );
    }
  }
}
