import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/domain/model/contact/contact_status.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class ContactStatusWidget extends StatelessWidget {
  final ContactStatus status;

  const ContactStatusWidget({super.key, required this.status});

  final Color inactiveColor = ZeonColors.outline;

  @override
  Widget build(BuildContext context) {
    return status == ContactStatus.inactive
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  ImagePaths.icStatus,
                  colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcIn),
                ),
                Text(
                  " ${L10n.of(context)!.inactive}",
                  style: const TextStyle(
                    color: ZeonColors.outline,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();
  }
}
