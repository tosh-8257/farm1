import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/account_context.dart';
import '/pages/business/business_ui.dart';

/// Personal / Business segmented switch. Switching never logs the user out.
class AccountSwitcherWidget extends StatelessWidget {
  const AccountSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = AccountContext.instance;
    return AnimatedBuilder(
      animation: ctx,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor(context)),
        ),
        child: Row(
          children: [
            _segment(context, 'Personal', AccountMode.personal, ctx),
            _segment(context, 'Business', AccountMode.business, ctx),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    AccountMode mode,
    AccountContext ctx,
  ) {
    final selected = ctx.mode == mode;
    final fg = fgColor(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label account',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ctx.setMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? fg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? FlutterFlowTheme.of(context).primaryBackground
                    : fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
