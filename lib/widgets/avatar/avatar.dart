import 'package:fluffychat/utils/string_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar_style.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final Uri? mxContent;
  final String? name;
  final double size;
  final void Function()? onTap;
  final double fontSize;
  final List<BoxShadow>? boxShadows;
  final Color? textColor;
  final bool keepAlive;
  final double borderRadius;

  const Avatar({
    this.mxContent,
    this.name,
    this.size = AvatarStyle.defaultSize,
    this.onTap,
    this.fontSize = AvatarStyle.defaultFontSize,
    this.boxShadows,
    this.textColor,
    this.keepAlive = false,
    this.borderRadius = _defaultCornerRadius,
    super.key,
  });

  static const double _defaultCornerRadius = 4.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0xFF474747),width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: MxcImage(
              key: Key(mxContent.toString()),
              uri: mxContent,
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context) * 2)
                  .round(),
              cacheKey: mxContent.toString(),
              animated: true,
              isThumbnail: false,
              placeholder: (context) => _fallbackAvatar(),
              keepAlive: keepAlive,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    final fallbackLetters = name?.getShortcutNameForAvatar() ?? '@';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2B),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadows,
      ),
      child: Center(
        child: Text(
          fallbackLetters,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor ?? Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
