import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/farm_coin_icon.dart';
import '/core/app_theme.dart';

/// High-contrast palette for the admin and super admin consoles (light).
/// Text colours meet WCAG AA (4.5:1) on white.
class AdminColors {
  static const text = Color(0xFF111111); // 18.9:1 on white
  static const textSecondary = Color(0xFF4B5563); // 7.6:1 on white
  static const border = Color(0xFFD1D5DB);
  static const iconTile = Color(0xFF111111);
  static const success = Color(0xFF15803D); // 5.0:1 on white
  static const error = Color(0xFFB91C1C); // 6.5:1 on white
  static const warning = Color(0xFF92400E); // 7.1:1 on white
  static Color get accent => AppTheme.accent;

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration card({double radius = 18}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: shadow,
      );
}

/// Shortens long identifiers (UUIDs, references) to `052a9…9c92`.
String shortId(Object? id, {int head = 5, int tail = 4}) {
  final s = (id ?? '').toString().trim();
  if (s.length <= head + tail + 1) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

/// Consistent FARM amount: `1,234.50` (no K/M abbreviations), optional sign.
String formatFarmAmount(Object? value, {String sign = ''}) {
  final n = double.tryParse('${value ?? 0}') ?? 0;
  final fixed = n.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign$whole.${parts[1]}';
}

/// FARM coin icon followed by an amount, on one line.
class FarmAmount extends StatelessWidget {
  const FarmAmount(this.value, {super.key, this.sign = '', this.color = AdminColors.text, this.size = 14});
  final Object? value;
  final String sign;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        FarmCoinIcon(size: size + 4),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${formatFarmAmount(value, sign: sign)} FARM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(color: color, fontSize: size, fontWeight: FontWeight.w800)),
        ),
      ]);
}

/// One row of recent activity: type, short reference, amount.
class AdminActivityTile extends StatelessWidget {
  const AdminActivityTile({super.key, required this.tx, this.onTap});
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;

  static const _credit = {'deposit', 'escrow_release', 'roi_payout'};

  @override
  Widget build(BuildContext context) {
    final type = '${tx['transaction_type'] ?? ''}';
    final isCredit = _credit.contains(type);
    final ref = tx['transaction_reference'] ?? tx['id'];
    final tone = isCredit ? AdminColors.success : AdminColors.error;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, color: tone, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type.replaceAll('_', ' ').toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.text, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(shortId(ref),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: AdminColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 8),
            FarmAmount(tx['amount'], sign: isCredit ? '+' : '−', color: tone, size: 14),
          ]),
        ),
      ),
    );
  }
}

/// Quick action tile for a 2-column grid: solid icon tile + label.
class AdminQuickActionTile extends StatelessWidget {
  const AdminQuickActionTile({super.key, required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: AdminColors.card(radius: 16),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AdminColors.iconTile, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
              ),
            ]),
          ),
        ),
      );
}

/// Quick actions laid out as an even 2-column grid (1 column when narrow).
class AdminQuickActionGrid extends StatelessWidget {
  const AdminQuickActionGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth < 300 ? 1 : (c.maxWidth > 700 ? 3 : 2);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: cols == 1 ? 5 : 2.6,
          children: children,
        );
      });
}

/// Pill for a status/KYC value with a solid, readable colour.
class AdminStatusTag extends StatelessWidget {
  const AdminStatusTag(this.text, this.color, {super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
                color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );
}

/// Maps a KYC status to an AA-contrast colour.
Color adminKycColor(Object? s) {
  switch ('$s') {
    case 'verified':
      return AdminColors.success;
    case 'pending':
      return AdminColors.warning;
    case 'rejected':
      return AdminColors.error;
    default:
      return AdminColors.textSecondary;
  }
}
