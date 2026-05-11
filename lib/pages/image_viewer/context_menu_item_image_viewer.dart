import 'package:fluffychat/pages/image_viewer/context_menu_item_image_viewer_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContextMenuItemImageViewer extends StatelessWidget {
  final String title;

  final IconData? icon;

  final String? imagePath;

  final bool haveDivider;

  final VoidCallback? onTap;

  const ContextMenuItemImageViewer({
    super.key,
    this.icon,
    this.imagePath,
    this.haveDivider = true,
    this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: ContextMenuItemImageViewerStyle.width,
          height: ContextMenuItemImageViewerStyle.height,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ContextMenuItemImageViewerStyle.paddingBetweenItems,
                    if (icon != null)
                      Icon(
                        icon,
                        color: const Color(0xFFE5E2E3),
                        size: 20,
                      ),
                    if (imagePath != null)
                      SvgPicture.asset(
                        imagePath!,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFE5E2E3),
                          BlendMode.srcIn,
                        ),
                      ),
                    ContextMenuItemImageViewerStyle.paddingBetweenItems,
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFE5E2E3),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (haveDivider)
                Divider(
                  height: ContextMenuItemImageViewerStyle.dividerHeight,
                  color: ContextMenuItemImageViewerStyle.dividerColor(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
