import 'package:flutter/material.dart';
import '/core/app_theme.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/backend/api_requests/business_api_service.dart';

/// Shared black/white/grey building blocks for the Business screens.

Color fgColor(BuildContext c) => FlutterFlowTheme.of(c).primaryText;
Color mutedColor(BuildContext c) => FlutterFlowTheme.of(c).secondaryText;
Color cardColor(BuildContext c) => FlutterFlowTheme.of(c).secondaryBackground;

/// Brand gold for headline money figures, darkened as needed for contrast
/// against the card surface.
Color goldOn(BuildContext c) => AppTheme.accentOn(cardColor(c));
Color borderColor(BuildContext c) => FlutterFlowTheme.of(c).alternate;

ButtonStyle primaryButtonStyle(BuildContext c) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  return ElevatedButton.styleFrom(
    backgroundColor: dark ? Colors.white : Colors.black,
    foregroundColor: dark ? Colors.black : Colors.white,
    disabledBackgroundColor: Colors.grey.shade400,
    disabledForegroundColor: Colors.grey.shade700,
    elevation: 0,
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

ButtonStyle secondaryButtonStyle(BuildContext c) => OutlinedButton.styleFrom(
  foregroundColor: fgColor(c),
  side: BorderSide(color: borderColor(c)),
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
);

class BizCard extends StatelessWidget {
  const BizCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor(context)),
    ),
    child: child,
  );
}

/// Monochrome status badge: filled for Approved, outlined otherwise.
class BusinessStatusBadge extends StatelessWidget {
  const BusinessStatusBadge({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final filled = status == BusinessStatus.approved;
    final fg = fgColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? fg : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? fg : mutedColor(context)),
      ),
      child: Text(
        BusinessStatus.label(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: filled ? FlutterFlowTheme.of(context).primaryBackground : fg,
        ),
      ),
    );
  }
}

class BizMessage extends StatelessWidget {
  const BizMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: fgColor(context)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: fgColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: mutedColor(context),
          ),
        ),
        if (action != null && actionLabel != null) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: action,
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

String friendlyError(Object e) {
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
