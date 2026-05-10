import 'dart:math';

import 'package:fluffychat/pages/chat_details/chat_details_group_description_view.dart';
import 'package:fluffychat/pages/chat_details/chat_details_header_stack.dart';
import 'package:fluffychat/pages/chat_details/chat_details_page_view/chat_details_page_enum.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatDetailsAppBar extends StatefulWidget {
  const ChatDetailsAppBar({
    super.key,
    required this.room,
    required this.onToggleNotification,
    required this.muteNotifier,
    required this.onSearch,
    required this.onMessage,
    required this.tabList,
    required this.tabController,
    required this.innerBoxIsScrolled,
  });

  final Room room;
  final VoidCallback onToggleNotification;
  final ValueNotifier<PushRuleState> muteNotifier;
  final VoidCallback onSearch;
  final VoidCallback onMessage;
  final bool innerBoxIsScrolled;
  final List<ChatDetailsPage> tabList;
  final TabController? tabController;

  @override
  State<ChatDetailsAppBar> createState() => _ChatDetailsAppBarState();
}

class _ChatDetailsAppBarState extends State<ChatDetailsAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;

  static const int _animationDuration = 100;
  static const double _groupInfoHeight = 224;
  static const double _actionsHeight = 69;
  static const double _actionsExpandedBottomPadding = 16;

  double descriptionHeight = 0;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _animationDuration),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void _handleGroupInfoTap() {
    if (animationController.isCompleted) {
      animationController.reverse();
    } else {
      animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverOverlapAbsorber(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: animationController,
            builder: (context, _) {
              final screenWidth = constraints.crossAxisExtent;
              double maxGroupInfoHeight =
                  screenWidth - _actionsHeight - _actionsExpandedBottomPadding;
              maxGroupInfoHeight = min(maxGroupInfoHeight, 300);

              final animatedGroupInfoHeight = Tween<double>(
                begin: _groupInfoHeight,
                end: maxGroupInfoHeight,
              ).transform(animationController.value);

              final animatedActionHeight = Tween<double>(
                begin: _actionsHeight,
                end: _actionsHeight + _actionsExpandedBottomPadding,
              ).transform(animationController.value);

              final toolbarHeight =
                  animatedGroupInfoHeight +
                  animatedActionHeight +
                  descriptionHeight;

              return SliverAppBar(
                backgroundColor: const Color(0xFF131314),
                toolbarHeight: toolbarHeight,
                title: ColoredBox(
                  color: const Color(0xFF131314),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatDetailsHeaderStack(
                        room: widget.room,
                        animationController: animationController,
                        groupInfoHeight: _groupInfoHeight,
                        maxGroupInfoHeight: maxGroupInfoHeight,
                        onMessage: widget.onMessage,
                        onSearch: widget.onSearch,
                        onToggleNotification: widget.onToggleNotification,
                        muteNotifier: widget.muteNotifier,
                        onGroupInfoTap: _handleGroupInfoTap,
                      ),
                      ChatDetailsGroupDescriptionView(
                        topic: widget.room.topic,
                        onHeightCalculated: (height) {
                          setState(() {
                            descriptionHeight = height;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                automaticallyImplyLeading: false,
                pinned: true,
                floating: true,
                forceElevated: widget.innerBoxIsScrolled,
                bottom: TabBar(
                  physics: const NeverScrollableScrollPhysics(),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorColor: Colors.white,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                  ),
                  indicatorWeight: 2.0,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    color: Color(0xFF636363),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: widget.tabList.map((page) {
                    return Tab(
                      child: Text(
                        page.getTitle(context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                    );
                  }).toList(),
                  controller: widget.tabController,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
