import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/pages/chat_profile_info/chat_profile_info.dart';
import 'package:fluffychat/pages/chat_profile_info/chat_profile_info_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class ChatProfileInfoView extends StatelessWidget {
  final ChatProfileInfoController controller;

  const ChatProfileInfoView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    final contact = controller.presentationContact;

    final headerWidget = ChatProfileInfoAppBar(
      userInfoNotifier: controller.userInfoNotifier,
      room: controller.room,
      user: user,
      presentationContact: contact,
      isAlreadyInChat: controller.isAlreadyInChat(context),
      tabList: controller.tabList,
      tabController: controller.tabController,
      isBlockedUserNotifier: controller.isBlockedUser,
      onUnblockUser: controller.onUnblockUser,
      onBlockUser: controller.onBlockUser,
      blockUserLoadingNotifier: controller.blockUserLoadingNotifier,
      onLeaveChat: controller.leaveChat,
      innerBoxIsScrolled: false,
      avatarUri: user?.avatarUrl,
      displayName: user?.calcDisplayname(),
      matrixId: user?.id,
      onMessage: controller.handleOnMessage,
    );

    return Scaffold(
      backgroundColor: ZeonColors.background,
      appBar: AppBar(
        backgroundColor: ZeonColors.background,
        surfaceTintColor: ZeonColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          L10n.of(context)!.contactInfo.toUpperCase(),
          style: const TextStyle(
            color: ZeonColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: controller.widget.onBack,
          icon: Icon(
            controller.widget.isInStack
                ? Icons.arrow_back_ios_new
                : Icons.close,
            color: ZeonColors.onSurface,
            size: 18,
          ),
        ),
      ),
      body: NestedScrollView(
        physics: controller.getScrollPhysics(),
        key: controller.nestedScrollViewState,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return headerWidget.buildSlivers(context);
        },
        body: Container(
          color: ZeonColors.background,
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: controller.tabController,
            children: controller.sharedPages().map((page) {
              return page.child;
            }).toList(),
          ),
        ),
      ),
    );
  }
}
