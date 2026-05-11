import 'package:fluffychat/pages/profile_info/copiable_profile_row/copiable_profile_row_style.dart';
import 'package:fluffychat/utils/clipboard.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:flutter/material.dart';

import 'package:fluffychat/generated/l10n/app_localizations.dart';

class CopiableProfileRow extends StatelessWidget {
  static const snackBarDuration = Duration(milliseconds: 500);

  final String caption;
  final String copiableText;
  final Widget leadingIcon;
  final bool enableDividerTop;

  const CopiableProfileRow({
    required this.leadingIcon,
    required this.caption,
    required this.copiableText,
    this.enableDividerTop = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CopiableProfileRowStyle.copiableRowPadding,
      child: InkWell(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: () {
          TwakeClipboard.instance.copyText(copiableText);
          TwakeSnackBar.show(
            duration: snackBarDuration,
            context,
            L10n.of(context)!.copiedToClipboard,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsGeometry.all(12),
              child: leadingIcon,
            ),
            const SizedBox(
              width: CopiableProfileRowStyle.spacerBetweenLeadingIconAndContent,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              style: const TextStyle(
                                color: Color(0xFF636363),
                                fontSize: 12,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              copiableText,
                              style: const TextStyle(
                                color: Color(0xFFE5E2E3),
                                fontSize: 15,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(38),
                        splashColor: const Color(0x1AE5E2E3),
                        onTap: () {
                          TwakeClipboard.instance.copyText(copiableText);
                          TwakeSnackBar.show(
                            duration: snackBarDuration,
                            context,
                            L10n.of(context)!.copiedToClipboard,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsetsGeometry.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.content_copy,
                              size: 18,
                              color: Color(0xFF636363),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (enableDividerTop)
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 16),
                      child: Divider(height: 1, color: Color(0x1F474747)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
