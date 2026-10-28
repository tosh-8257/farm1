import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';

class KycManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const KycManagementPage({super.key, this.onGoBack});

  @override
  State<KycManagementPage> createState() => _KycManagementPageState();
}

class _KycManagementPageState extends State<KycManagementPage>
    with AdminPageRefreshMixin<KycManagementPage> {
  List<dynamic> _queue = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String _status = 'pending';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await AdminApiService.getKycQueue(page: _page, status: _status);
      setState(() => _queue = res['data'] ?? []);
    } catch (e) {
      if (mounted && _queue.isEmpty) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  Future<void> _review(String docId, String status, {String? reason}) async {
    try {
      await AdminApiService.reviewKyc(docId, status, rejectionReason: reason);
      _snack(status == 'verified' ? 'KYC Approved ✓' : 'KYC Rejected',
          status == 'verified' ? context.successColor : context.errorColor);
      _load();
    } catch (e) {
      _snack(e.toString(), context.errorColor);
    }
  }

  void _showRejectDialog(String docId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject KYC',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'Reason for rejection...',
              border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: context.errorColor),
            onPressed: () {
              Navigator.pop(context);
              _review(docId, 'rejected', reason: ctrl.text.trim());
            },
            child: Text('Reject'),
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

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        child: Row(children: [
          IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed:
                widget.onGoBack ?? () => Navigator.of(context).maybePop(),
          ),
          Text('KYC Management',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
      ),
      if (_loading && _queue.isEmpty)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_error != null && _queue.isEmpty)
        Expanded(
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Text(_error!),
              ElevatedButton(onPressed: _load, child: const Text('Retry'))
            ])))
      else ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            for (final value in ['pending', 'rejected', 'all'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                    label: Text(value.toUpperCase()),
                    selected: _status == value,
                    onSelected: (_) {
                      setState(() => _status = value);
                      _load();
                    }),
              ),
          ]),
        ),
        Expanded(
            child: RefreshIndicator(
          onRefresh: _load,
          child: _queue.isEmpty
              ? Center(child: Text('No pending KYC applications'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _queue
                          .where((doc) =>
                              _search.isEmpty ||
                              doc
                                  .toString()
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()))
                          .length +
                      1,
                  itemBuilder: (_, i) {
                    if (i == 0)
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                  hintText:
                                      'Search name, username, ID or document number',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  border: OutlineInputBorder()),
                              onChanged: (value) =>
                                  setState(() => _search = value)));
                    final visible = _queue
                        .where((doc) =>
                            _search.isEmpty ||
                            doc
                                .toString()
                                .toLowerCase()
                                .contains(_search.toLowerCase()))
                        .toList();
                    return _kycCard(visible[i - 1]);
                  },
                ),
        )),
      ],
    ]);
  }

  Widget _kycCard(Map<String, dynamic> doc) {
    final user = doc['users_kyc_documents_user_idTousers'] as Map? ?? doc;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showKycDetails(doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: context.onSurface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              const BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8)
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(255, 165, 0, 0.15),
                  radius: 22,
                  child:
                      Icon(Icons.person_rounded, color: context.warningColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(user['phone'] ?? '-',
                          style: GoogleFonts.plusJakartaSans(
                              color: context.textSecondary, fontSize: 12)),
                      Text('Doc: ${doc['document_type'] ?? 'N/A'}',
                          style: GoogleFonts.plusJakartaSans(
                              color: context.textSecondary, fontSize: 12)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 165, 0, 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('PENDING',
                      style: GoogleFonts.plusJakartaSans(
                          color: context.warningColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showKycDetails(doc),
                  icon: Icon(Icons.info_outline, size: 16),
                  label: Text('View details'),
                ),
              ),
            ),
            if (doc['document_number'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SelectableText(
                  'ID: ${doc['document_number']}',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((doc['first_name'] ?? doc['last_name']) != null)
                      _detailRow(
                          'Name',
                          '${doc['first_name'] ?? ''} ${doc['last_name'] ?? ''}'
                              .trim()),
                    if (doc['date_of_birth'] != null)
                      _detailRow(
                          'Date of Birth', doc['date_of_birth']?.toString()),
                    if (doc['gender'] != null)
                      _detailRow('Gender', doc['gender']?.toString()),
                    if (doc['nationality'] != null)
                      _detailRow('Nationality', doc['nationality']?.toString()),
                    if (doc['email'] != null)
                      _detailRow('Email', doc['email']?.toString()),
                    if (doc['phone'] != null)
                      _detailRow('Phone', doc['phone']?.toString()),
                    if (doc['country'] != null ||
                        doc['county'] != null ||
                        doc['city'] != null ||
                        doc['physical_address'] != null ||
                        doc['postal_code'] != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 6),
                        child: Text('Address',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    if (doc['country'] != null)
                      _detailRow('Country', doc['country']?.toString()),
                    if (doc['county'] != null)
                      _detailRow('State / County', doc['county']?.toString()),
                    if (doc['city'] != null)
                      _detailRow('City', doc['city']?.toString()),
                    if (doc['physical_address'] != null)
                      _detailRow(
                          'Address', doc['physical_address']?.toString()),
                    if (doc['postal_code'] != null)
                      _detailRow('Postal Code', doc['postal_code']?.toString()),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _documentImagesSection(doc),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.errorColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: Icon(Icons.close_rounded,
                        color: context.errorColor, size: 16),
                    label: Text('Reject',
                        style: GoogleFonts.plusJakartaSans(
                            color: context.errorColor)),
                    onPressed: () => _showRejectDialog(doc['id']),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.successColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: Icon(Icons.check_rounded, size: 16),
                    label:
                        Text('Approve', style: GoogleFonts.plusJakartaSans()),
                    onPressed: () => _review(doc['id'], 'verified'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showKycDetails(Map<String, dynamic> doc) {
    // Fetch full doc from API to ensure we display all available fields and images
    showDialog(
      context: context,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: AdminApiService.getKycDoc(doc['id']?.toString() ?? ''),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()));
          if (snap.hasError)
            return AlertDialog(
                title: const Text('Error'),
                content: Text(snap.error.toString()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]);
          final d = (snap.data?['data'] ?? {}) as Map<String, dynamic>;
          final user = d['users_kyc_documents_user_idTousers'] as Map? ?? {};
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            title: Text('KYC Application',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prominent uploader info
                    Row(children: [
                      CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFEAF2FF),
                          child:
                              Icon(Icons.person, color: context.primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user['username'] != null)
                                Text('@${user['username']}',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold)),
                              if (user['email'] != null)
                                Text(user['email'],
                                    style: GoogleFonts.plusJakartaSans(
                                        color: context.textSecondary,
                                        fontSize: 12)),
                              if (user['phone'] != null)
                                Text(user['phone'],
                                    style: GoogleFonts.plusJakartaSans(
                                        color: context.textSecondary,
                                        fontSize: 12)),
                            ]),
                      )
                    ]),
                    const SizedBox(height: 12),
                    _detailRow(
                        'Name',
                        '${d['first_name'] ?? user['first_name'] ?? ''} ${d['last_name'] ?? user['last_name'] ?? ''}'
                            .trim()),
                    _detailRow('Email',
                        d['email']?.toString() ?? user['email']?.toString()),
                    _detailRow('Phone',
                        d['phone']?.toString() ?? user['phone']?.toString()),
                    const Divider(height: 24),
                    _detailRow('Document type', d['document_type']?.toString()),
                    _detailRow(
                        'Document number', d['document_number']?.toString()),
                    _detailRow('Date of birth', d['date_of_birth']?.toString()),
                    _detailRow('Gender', d['gender']?.toString()),
                    _detailRow('Nationality', d['nationality']?.toString()),
                    const Divider(height: 24),
                    _detailRow('Country', d['country']?.toString()),
                    _detailRow('State / County', d['county']?.toString()),
                    _detailRow('City', d['city']?.toString()),
                    _detailRow('Address', d['physical_address']?.toString()),
                    _detailRow('Postal code', d['postal_code']?.toString()),
                    _documentImagesSection(d),
                    if (d['additional_documents'] != null &&
                        d['additional_documents'] is List)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Additional documents',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ...List<Widget>.from(
                                    (d['additional_documents'] as List)
                                        .map((doc) {
                                  final url = doc is Map
                                      ? (doc['url'] ?? doc['src'])?.toString()
                                      : null;
                                  if (url == null) return const SizedBox();
                                  return GestureDetector(
                                    onTap: () => _openImageGallery([(url)], 0),
                                    child: Container(
                                      width: 120,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: context.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }))
                              ])
                            ]),
                      ),
                  ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRejectDialog(d['id']);
                  },
                  child: Text('Reject',
                      style: TextStyle(color: context.errorColor))),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _review(d['id'], 'verified');
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: context.successColor),
                child: const Text('Approve'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _documentImagesSection(Map<dynamic, dynamic> d) {
    final images = <MapEntry<String, String?>>[
      MapEntry('Front ID', _imageUrl(d, 'front_image')),
      MapEntry('Back ID', _imageUrl(d, 'back_image')),
      MapEntry('Selfie', _imageUrl(d, 'selfie_image')),
      MapEntry('Address proof', _imageUrl(d, 'address_document')),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Submitted images',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final image in images)
              _docImg(image.key, image.value, document: d),
          ],
        )
      ]),
    );
  }

  String? _imageUrl(Map<dynamic, dynamic> document, String imageField) {
    final value = document['${imageField}_url'] ?? document[imageField];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map && value['url'] is String) {
      final url = (value['url'] as String).trim();
      return url.isEmpty ? null : url;
    }
    return null;
  }

  void _openImageGallery(List<String> urls, int initialIndex) {
    final controller = PageController(initialPage: initialIndex);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(0),
        child: Stack(children: [
          PageView.builder(
            controller: controller,
            itemCount: urls.length,
            itemBuilder: (context, i) => InteractiveViewer(
                child: Image.network(
              urls[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('Image unavailable')),
            )),
          ),
          Positioned(
            top: 24,
            left: 12,
            child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
          ),
          Positioned(
            top: 24,
            right: 12,
            child: Row(children: [
              IconButton(
                  tooltip: 'Open image in browser',
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () async {
                    final index = controller.hasClients
                        ? controller.page?.round() ?? initialIndex
                        : initialIndex;
                    await _openKycImage(urls[index]);
                  }),
              IconButton(
                  tooltip: 'Copy image URL',
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () async {
                    final url = urls[controller.hasClients
                        ? controller.page?.round() ?? initialIndex
                        : initialIndex];
                    await Clipboard.setData(ClipboardData(text: url));
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Image URL copied to clipboard')));
                  }),
            ]),
          )
        ]),
      ),
    );
  }

  Future<void> _openKycImage(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'res.cloudinary.com') {
      _snack('The KYC image link is invalid.', context.errorColor);
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _snack('Could not open the KYC image.', context.errorColor);
      }
    } catch (error) {
      if (mounted) {
        _snack('Could not open the KYC image: $error', context.errorColor);
      }
    }
  }

  Widget _docImg(
    String label,
    String? url, {
    required Map<dynamic, dynamic> document,
  }) {
    final imageUrls = [
      for (final field in [
        'front_image',
        'back_image',
        'selfie_image',
        'address_document',
      ])
        if (_imageUrl(document, field) case final imageUrl?) imageUrl,
    ];

    return SizedBox(
      width: 160,
      child: Column(children: [
        Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: url == null
                ? null
                : () => _openImageGallery(imageUrls, imageUrls.indexOf(url)),
            child: SizedBox(
              width: 160,
              height: 110,
              child: url == null
                  ? _imagePlaceholder('Not uploaded')
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _imagePlaceholder('Loading image...');
                      },
                      errorBuilder: (_, __, ___) =>
                          _imagePlaceholder('Image unavailable'),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: context.textSecondary)),
      ]),
    );
  }

  Widget _imagePlaceholder(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined, size: 24),
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _detailRow(String label, String? value) {
    if (value == null || value.toString().trim().isEmpty)
      return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 104,
          child: Text('$label:',
              style: GoogleFonts.plusJakartaSans(
                  color: context.onBackground.withOpacity(0.87),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value.toString(),
              softWrap: true,
              style: GoogleFonts.plusJakartaSans(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
