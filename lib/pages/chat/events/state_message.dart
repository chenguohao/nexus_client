import 'package:flutter/material.dart';

import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';

class StateMessage extends StatelessWidget {
  final Event event;
  const StateMessage(this.event, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FutureBuilder<String>(
            future: event.calcLocalizedBody(MatrixLocals(L10n.of(context)!)),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ??
                    event.calcLocalizedBodyFallback(
                      MatrixLocals(L10n.of(context)!),
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFC6C6C6).withOpacity(0.70),
                  fontSize: 12,
                  fontFamily: 'Inter',
                  decoration: event.redacted
                      ? TextDecoration.lineThrough
                      : null,
                  letterSpacing: 0.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
