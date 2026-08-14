import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full ICCID + copy. Never logs the value.
class IccidCopyRow extends StatelessWidget {
  const IccidCopyRow({
    super.key,
    required this.iccid,
    required this.color,
    required this.copied,
    required this.onCopied,
  });

  final String iccid;
  final Color color;
  final bool copied;
  final VoidCallback onCopied;

  bool get _hasIccid => iccid.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final display = _hasIccid ? iccid.trim() : '—';
    return Row(
      children: [
        Icon(Icons.sim_card_outlined, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ),
        if (copied)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Copied',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Copy ICCID',
            visualDensity: VisualDensity.compact,
            onPressed: _hasIccid ? _copy : null,
            icon: Icon(Icons.copy_outlined, color: color, size: 20),
          ),
      ],
    );
  }

  void _copy() {
    onCopied();
    unawaited(Clipboard.setData(ClipboardData(text: iccid.trim())));
  }
}
