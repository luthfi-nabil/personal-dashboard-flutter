import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../theme/app_theme.dart';

class SourceCard extends StatelessWidget {
  final Source source;
  final double? balance;
  final String currency;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SourceCard({
    super.key,
    required this.source,
    this.balance,
    required this.currency,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final tone = sourceTone(source.name);
    final bal = balance ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line2, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: tone.tone,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  tone.m,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: c.ink)),
                  Text(source.kind,
                      style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            if (balance != null)
              Text(
                fmtRp(bal, currency),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: bal < 0 ? c.neg : c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
