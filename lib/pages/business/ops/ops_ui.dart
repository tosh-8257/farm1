import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '../business_ui.dart';

export '../business_ui.dart';

String money(dynamic v, [String currency = 'FARM']) {
  final n = v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  final s = n.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (m) => '${m[1]},',
      );
  return '$s $currency';
}

String shortDate(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Standard page frame for business screens (black/white/grey only).
class BizScaffold extends StatelessWidget {
  const BizScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fab,
    this.actions,
  });
  final String title;
  final Widget body;
  final Widget? fab;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          foregroundColor: fgColor(context),
          elevation: 0,
          title: Text(title,
              style: TextStyle(
                  color: fgColor(context), fontWeight: FontWeight.w700)),
          actions: actions,
        ),
        floatingActionButton: fab,
        body: SafeArea(child: body),
      );
}

class BizFab extends StatelessWidget {
  const BizFab({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FloatingActionButton.extended(
      backgroundColor: dark ? Colors.white : Colors.black,
      foregroundColor: dark ? Colors.black : Colors.white,
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

/// Loads [load] and renders loading / error+retry / empty / content states.
class BizAsync<T> extends StatefulWidget {
  const BizAsync({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = '',
    this.emptyIcon = Icons.inbox_outlined,
  });
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  final bool Function(T)? isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  State<BizAsync<T>> createState() => BizAsyncState<T>();
}

class BizAsyncState<T> extends State<BizAsync<T>> {
  bool _loading = true;
  String? _error;
  T? _data;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return Center(
        child: SingleChildScrollView(
          child: BizMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            message: _error!,
            action: reload,
            actionLabel: 'Retry',
          ),
        ),
      );
    }
    final d = _data as T;
    if (widget.isEmpty?.call(d) ?? false) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(children: [
          const SizedBox(height: 60),
          BizMessage(
            icon: widget.emptyIcon,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          ),
        ]),
      );
    }
    return RefreshIndicator(
        onRefresh: reload, child: widget.builder(context, d, reload));
  }
}

/// Outlined/filled monochrome chip for any status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.filled = false});
  final String label;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final fg = fgColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? fg : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? fg : mutedColor(context)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled
                  ? FlutterFlowTheme.of(context).primaryBackground
                  : fg)),
    );
  }
}

class BizTile extends StatelessWidget {
  const BizTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? leading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: BizCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (leading != null) ...[
                Icon(leading, color: fgColor(context)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: fgColor(context))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 13, color: mutedColor(context))),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      );
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key});
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(k, style: TextStyle(color: mutedColor(context)))),
          Expanded(
              child: SelectableText(v,
                  style: TextStyle(
                      color: fgColor(context), fontWeight: FontWeight.w500))),
        ]),
      );
}

InputDecoration bizInput(BuildContext c, String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: mutedColor(c)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor(c))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fgColor(c))),
    );

void bizSnack(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

/// Plain confirmation for sensitive actions.
Future<bool> confirmAction(BuildContext c,
    {required String title, required String message, String confirm = 'Confirm'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm,
                style: TextStyle(
                    color: fgColor(ctx), fontWeight: FontWeight.w700))),
      ],
    ),
  );
  return r ?? false;
}

/// Confirmation with transaction PIN. Returns the PIN, or null if cancelled.
Future<String?> confirmWithPin(BuildContext c,
    {required String title, required String message}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message),
        const SizedBox(height: 16),
        TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: bizInput(ctx, 'Transaction PIN'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
        TextButton(
            onPressed: () {
              if (ctrl.text.length >= 4) Navigator.pop(ctx, ctrl.text);
            },
            child: Text('Confirm',
                style: TextStyle(
                    color: fgColor(ctx), fontWeight: FontWeight.w700))),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

/// Runs [action] with a blocking spinner and reports errors.
Future<T?> runBusy<T>(BuildContext c, Future<T> Function() action,
    {String? success}) async {
  showDialog(
      context: c,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final r = await action();
    if (c.mounted) {
      Navigator.of(c, rootNavigator: true).pop();
      if (success != null) bizSnack(c, success);
    }
    return r;
  } catch (e) {
    if (c.mounted) {
      Navigator.of(c, rootNavigator: true).pop();
      bizSnack(c, friendlyError(e));
    }
    return null;
  }
}

Future<T?> pushPage<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => page));
