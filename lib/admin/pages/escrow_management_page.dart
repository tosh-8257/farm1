import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';

class EscrowManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;
  final String initialFilter;

  const EscrowManagementPage({
    super.key,
    this.onGoBack,
    this.initialFilter = 'all',
  });

  @override
  State<EscrowManagementPage> createState() => _EscrowManagementPageState();
}

class _EscrowManagementPageState extends State<EscrowManagementPage>
    with AdminPageRefreshMixin<EscrowManagementPage> {
  List<dynamic> _escrows = [];
  bool _loading = true;
  late String _filter;
  int _page = 1;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filter = const ['all', 'active', 'completed', 'disputed', 'refunded']
            .contains(widget.initialFilter)
        ? widget.initialFilter
        : 'all';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getEscrows(
          page: _page, status: _filter == 'all' ? null : _filter);
      setState(() => _escrows = res['data'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  Future<void> _resolve(String escrowId, String winner) async {
    final ctrl = TextEditingController();
    final outcome = winner == 'buyer' ? 'refund to buyer' : 'release to seller';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Resolve Dispute — $outcome',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold, color: context.onSurface)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: context.onSurface),
          decoration: InputDecoration(
              hintText: 'Resolution note...',
              hintStyle: TextStyle(color: context.onSurface.withOpacity(0.54)),
              border: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.onSurface.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.onSurface.withOpacity(0.1)))),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface.withOpacity(0.7)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AdminApiService.resolveDispute(
                    escrowId, winner, ctrl.text.trim());
                _snack(
                  winner == 'buyer'
                      ? 'Dispute resolved — funds refunded to buyer'
                      : 'Dispute resolved — funds released to seller',
                  context.successColor,
                );
                _load();
              } catch (e) {
                _snack(e.toString(), context.errorColor);
              }
            },
            child: Text('Confirm',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onAccent)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating));

  Color _escrowColor(String? s) {
    switch (s) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return context.successColor;
      case 'disputed':
        return context.errorColor;
      case 'refunded':
        return context.warningColor;
      default:
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white;
    final cardColor = Colors.white;
    final accent = AppTheme.accentOn(bgColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(children: [
                IconButton(
                  tooltip: 'Go back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed:
                      widget.onGoBack ?? () => Navigator.of(context).maybePop(),
                ),
                Text('Escrow Management',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
            _filterRow(accent),
            if (_loading && _escrows.isEmpty)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF90CAF9))))
            else
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _load,
                      color: accent,
                      child: _escrows.isEmpty
                          ? Center(
                              child: Text('No escrow contracts',
                                  style: GoogleFonts.plusJakartaSans(
                                      color:
                                          context.onSurface.withOpacity(0.6))))
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _escrows
                                  .where((e) =>
                                      _search.isEmpty ||
                                      e
                                          .toString()
                                          .toLowerCase()
                                          .contains(_search.toLowerCase()))
                                  .length,
                              itemBuilder: (_, i) {
                                final visible = _escrows
                                    .where((e) =>
                                        _search.isEmpty ||
                                        e
                                            .toString()
                                            .toLowerCase()
                                            .contains(_search.toLowerCase()))
                                    .toList();
                                return _escrowCard(
                                    visible[i], cardColor, accent);
                              },
                            ))),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(Color accent) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                    hintText: 'Search username, escrow ID or reference',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder()),
                onChanged: (value) => setState(() => _search = value))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            for (final f in [
              'all',
              'active',
              'completed',
              'disputed',
              'refunded'
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _filter == f ? AppTheme.onAccent : Colors.black)),
                  selected: _filter == f,
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: _filter == f ? AppTheme.accent : Colors.black54,
                      width: 1),
                  onSelected: (_) {
                    setState(() {
                      _filter = f;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
          ]),
        ),
      ]);

  Widget _escrowCard(Map<String, dynamic> e, Color cardColor, Color accent) {
    final buyer = e['users_escrow_contracts_buyer_idTousers'] as Map? ?? {};
    final seller = e['users_escrow_contracts_seller_idTousers'] as Map? ?? {};
    final color = _escrowColor(e['status']);
    final isDisputed = e['status'] == 'disputed';
    final evidence = _asStringMap(e['evidence']);
    final buyerUsername = (buyer['username']?.toString() ?? '').trim();
    final sellerUsername = (seller['username']?.toString() ?? '').trim();
    final buyerLabel = buyerUsername.isNotEmpty
        ? '@$buyerUsername (${buyer['id'] ?? '-'} )'
        : '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}'
                .trim()
                .isNotEmpty
            ? '${buyer['first_name']} ${buyer['last_name']}'
            : (buyer['id']?.toString() ?? '-');
    final sellerLabel = sellerUsername.isNotEmpty
        ? '@$sellerUsername (${seller['id'] ?? '-'} )'
        : '${seller['first_name'] ?? ''} ${seller['last_name'] ?? ''}'
                .trim()
                .isNotEmpty
            ? '${seller['first_name']} ${seller['last_name']}'
            : (seller['id']?.toString() ?? '-');
    final createdAt = e['created_at'] != null
        ? _dateTimeString(e['created_at'].toString())
        : '-';
    final resolvedAt = e['resolved_at'] ?? e['released_at'] ?? e['updated_at'];
    final resolvedAtLabel =
        resolvedAt != null ? _dateTimeString(resolvedAt.toString()) : null;
    final description = e['description']?.toString().trim().isNotEmpty == true
        ? e['description'].toString()
        : e['title']?.toString() ?? '-';
    final disputeReason = evidence['reason']?.toString().trim() ?? '';
    final disputedById = evidence['disputed_by']?.toString();
    final disputedBy =
        disputedById != null && disputedById == buyer['id']?.toString()
            ? 'Buyer'
            : disputedById != null && disputedById == seller['id']?.toString()
                ? 'Seller'
                : 'A party';
    final disputeMessages = e['escrow_messages'] is List
        ? (e['escrow_messages'] as List)
            .map(_asStringMap)
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final messageAttachment = disputeMessages
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (message) =>
              message?['attachment_url']?.toString().trim().isNotEmpty == true,
          orElse: () => null,
        );
    final attachmentUrl =
        (evidence['attachment_url'] ?? messageAttachment?['attachment_url'])
            ?.toString()
            .trim();
    final attachmentMimeType =
        evidence['attachment_mime_type']?.toString() ?? '';
    final hasDisputeEvidence =
        disputeReason.isNotEmpty || (attachmentUrl?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: isDisputed
            ? Border.all(
                color: context.errorColor.withAlpha((0.4 * 255).round()),
                width: 1.5)
            : Border.all(color: context.onSurface.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: SelectableText(
              e['reference_code']?.toString() ?? e['id']?.toString() ?? '',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 13, color: accent),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color.withAlpha((0.16 * 255).round()),
                borderRadius: BorderRadius.circular(8)),
            child: Text((e['status'] ?? '').toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        _escrowDetail('Escrow ID', e['id']?.toString() ?? '-'),
        _escrowDetail('Description', description),
        _escrowDetail('Amount',
            '${double.tryParse(e['amount']?.toString() ?? '0')?.toStringAsFixed(2)} FARM'),
        _escrowDetail('Buyer', buyerLabel),
        _escrowDetail('Seller', sellerLabel),
        _escrowDetail('Created', createdAt),
        if (resolvedAtLabel != null)
          _escrowDetail(
              e['status'] == 'completed'
                  ? 'Released'
                  : e['status'] == 'refunded'
                      ? 'Refunded'
                      : 'Updated',
              resolvedAtLabel),
        if (isDisputed || hasDisputeEvidence) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.errorColor.withAlpha((0.08 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isDisputed ? 'Dispute open' : 'Dispute evidence',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: context.errorColor,
                      fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                  disputeReason.isNotEmpty
                      ? 'Reported by $disputedBy: $disputeReason'
                      : 'This escrow is in dispute and requires admin resolution.',
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface.withOpacity(0.8), fontSize: 12)),
              if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _disputeAttachment(attachmentUrl, attachmentMimeType),
              ],
            ]),
          ),
          if (isDisputed) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _resolve(e['id'], 'buyer'),
                  child: Text('Refund Buyer',
                      style: GoogleFonts.plusJakartaSans(color: Colors.blue)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: context.successColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _resolve(e['id'], 'seller'),
                  child: Text('Release to Seller',
                      style: GoogleFonts.plusJakartaSans(
                          color: context.onBackground.withOpacity(0.87))),
                ),
              ),
            ]),
          ],
        ],
      ]),
    );
  }

  Widget _disputeAttachment(String url, String mimeType) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com') {
      return _attachmentPlaceholder(
        icon: Icons.broken_image_outlined,
        title: 'User attachment unavailable',
        subtitle: 'The dispute attachment link is invalid.',
      );
    }

    final isVideo = mimeType.toLowerCase().startsWith('video/') ||
        uri.path.toLowerCase().contains('/video/upload/');
    if (isVideo) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.play_circle_outline),
          ),
          title: const Text('User attached a video'),
          subtitle: const Text('Tap to view dispute evidence'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _openDisputeAttachment(uri),
        ),
      );
    }

    final previewUri = uri.replace(
      path: uri.path.replaceFirst('/upload/', '/upload/f_jpg,q_auto/'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('User attached a photo'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.network(
                  previewUri.toString(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => _attachmentPlaceholder(
                    icon: Icons.broken_image_outlined,
                    title: 'Could not load the user photo',
                    subtitle: 'Tap “Open photo” to view it directly.',
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              previewUri.toString(),
              width: 260,
              height: 190,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 260,
                  height: 190,
                  color: context.onSurface.withOpacity(0.06),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading user photo...'),
                    ],
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _attachmentPlaceholder(
                icon: Icons.broken_image_outlined,
                title: 'Could not load the user photo',
                subtitle: 'Tap “Open photo” to view it directly.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => _openDisputeAttachment(uri),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open photo'),
        ),
      ],
    );
  }

  Widget _attachmentPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.onSurface.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.onSurface.withOpacity(0.65)),
            ),
          ],
        ),
      );

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  Future<void> _openDisputeAttachment(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _snack('Could not open the dispute attachment.', context.errorColor);
      }
    } catch (error) {
      if (mounted) {
        _snack('Could not open the dispute attachment: $error',
            context.errorColor);
      }
    }
  }

  String _dateTimeString(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Widget _escrowDetail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface.withOpacity(0.54),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
}
