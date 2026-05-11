import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

enum ProfileInfoActions {
  sendMessage,
  downgradeToReadOnly,
  removeFromGroup,
  transferOwnership;

  String label(BuildContext context) {
    switch (this) {
      case ProfileInfoActions.sendMessage:
        return L10n.of(context)!.sendMessage;
      case ProfileInfoActions.removeFromGroup:
        return L10n.of(context)!.removeFromGroup;
      case ProfileInfoActions.downgradeToReadOnly:
        return L10n.of(context)!.downgradeToReadOnly;
      case ProfileInfoActions.transferOwnership:
        return L10n.of(context)!.transferOwnership;
    }
  }

  TextStyle textStyle(BuildContext context) {
    switch (this) {
      case ProfileInfoActions.sendMessage:
        return const TextStyle(
          color: Color(0xFFE5E2E3),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
      case ProfileInfoActions.removeFromGroup:
        return const TextStyle(
          color: Color(0xFFCF6679),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
      case ProfileInfoActions.downgradeToReadOnly:
      case ProfileInfoActions.transferOwnership:
        return const TextStyle(
          color: Color(0xFF919191),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    }
  }

  Decoration? decoration(BuildContext context) {
    switch (this) {
      case ProfileInfoActions.sendMessage:
        return BoxDecoration(
          color: const Color(0xFF2A2A2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33474747)),
        );
      case ProfileInfoActions.removeFromGroup:
      case ProfileInfoActions.downgradeToReadOnly:
      case ProfileInfoActions.transferOwnership:
        return null;
    }
  }

  EdgeInsetsGeometry padding(BuildContext context) {
    switch (this) {
      case ProfileInfoActions.sendMessage:
        return const EdgeInsets.only(top: 16, bottom: 8);
      case ProfileInfoActions.removeFromGroup:
        return const EdgeInsets.only(top: 8, bottom: 8);
      case ProfileInfoActions.downgradeToReadOnly:
      case ProfileInfoActions.transferOwnership:
        return const EdgeInsets.only(bottom: 8);
    }
  }

  Divider? divider(BuildContext context) {
    switch (this) {
      case ProfileInfoActions.removeFromGroup:
      case ProfileInfoActions.transferOwnership:
        return const Divider(
          thickness: 1,
          color: Color(0x1F474747),
        );
      case ProfileInfoActions.sendMessage:
      case ProfileInfoActions.downgradeToReadOnly:
        return null;
    }
  }

  Icon? icon() {
    switch (this) {
      case ProfileInfoActions.sendMessage:
        return const Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: Color(0xFFE5E2E3),
        );
      case ProfileInfoActions.removeFromGroup:
        return const Icon(
          Icons.delete_outline_outlined,
          size: 18,
          color: Color(0xFFCF6679),
        );
      case ProfileInfoActions.transferOwnership:
        return const Icon(
          Icons.swap_horiz_rounded,
          size: 18,
          color: Color(0xFF919191),
        );
      case ProfileInfoActions.downgradeToReadOnly:
        return null;
    }
  }
}
