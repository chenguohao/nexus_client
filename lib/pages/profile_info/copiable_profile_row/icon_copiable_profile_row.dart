import 'package:fluffychat/pages/profile_info/copiable_profile_row/copiable_profile_row.dart';
import 'package:flutter/material.dart';

class IconCopiableProfileRow extends CopiableProfileRow {
  IconCopiableProfileRow({
    required IconData icon,
    required super.caption,
    required super.copiableText,
    super.key,
    super.enableDividerTop,
  }) : super(
         leadingIcon: Icon(
           icon,
           size: 20,
           color: const Color(0xFF636363),
         ),
       );
}
