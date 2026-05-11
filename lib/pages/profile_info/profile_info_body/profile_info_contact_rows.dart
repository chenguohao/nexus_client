import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/app_state/user_info/get_user_info_state.dart';
import 'package:fluffychat/pages/profile_info/copiable_profile_row/icon_copiable_profile_row.dart';
import 'package:flutter/material.dart';

import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

class ProfileInfoContactRows extends StatelessWidget {
  const ProfileInfoContactRows({
    required this.user,
    required this.userInfoNotifier,
    super.key,
  });

  final User user;
  final ValueNotifier<Either<Failure, Success>> userInfoNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userInfoNotifier,
      builder: (context, userInfo, child) {
        final userInfoModel =
            userInfo.getSuccessOrNull<GetUserInfoSuccess>()?.userInfo;
        final isLoading = userInfo is GettingUserInfo;

        final hasPhone = userInfoModel?.phones?.firstOrNull != null;
        final hasEmail = userInfoModel?.emails?.firstOrNull != null;

        // 没有额外信息时隐藏整块
        if (!isLoading && !hasPhone && !hasEmail) {
          return const SizedBox.shrink();
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x1F474747)),
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF1C1B1C),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    _LoadingPlaceholder()
                  else ...[
                    if (hasPhone)
                      IconCopiableProfileRow(
                        icon: Icons.call,
                        caption: L10n.of(context)!.phone,
                        copiableText: userInfoModel!.phones!.firstOrNull ?? '',
                        enableDividerTop: hasEmail,
                      ),
                    if (hasEmail)
                      IconCopiableProfileRow(
                        icon: Icons.alternate_email,
                        caption: L10n.of(context)!.email,
                        copiableText: userInfoModel!.emails!.firstOrNull ?? '',
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [_ShimmerRow(), const SizedBox(height: 8), _ShimmerRow()],
      ),
    );
  }
}

class _ShimmerRow extends StatefulWidget {
  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFF2A2A2B),
                Color(0xFF1C1B1C),
                Color(0xFF2A2A2B),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
