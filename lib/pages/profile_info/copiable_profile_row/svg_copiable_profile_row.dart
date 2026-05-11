import 'package:fluffychat/pages/profile_info/copiable_profile_row/copiable_profile_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgCopiableProfileRow extends CopiableProfileRow {
  SvgCopiableProfileRow({
    required String leadingIconPath,
    required super.caption,
    required super.copiableText,
    super.enableDividerTop,
    super.key,
  }) : super(
         leadingIcon: SvgPicture.asset(
           leadingIconPath,
           width: 20,
           height: 20,
           colorFilter: const ColorFilter.mode(
             Color(0xFF636363),
             BlendMode.srcIn,
           ),
         ),
       );
}
