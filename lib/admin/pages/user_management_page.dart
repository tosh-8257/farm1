import 'package:flutter/material.dart';
import '/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';
import '/utils/user_error_message.dart';

class UserManagementPage extends StatefulWidget {
  static const String routeName = 'user_management';
  static const String routePath = '/admin/users';

  final VoidCallback? onGoBack;

  const UserManagementPage({super.key, this.onGoBack});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with AdminPageRefreshMixin<UserManagementPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _search = '';
  int _page = 1;
  int _total = 0;
  int _totalUsers = 0;
  int _verifiedCount = 0;
  int _pendingCount = 0;
  int _rejectedCount = 0;
  final _searchCtrl = TextEditingController();

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
      final res = await AdminApiService.getUsers(
        page: _page,
        search: _search.isNotEmpty ? _search : null,
        kycStatus: _filter == 'all' ? null : _filter,
      );
      setState(() {
        _users = res['data'] ?? [];
        _total = res['meta']?['total'] ?? 0;
      });
      await _loadSummaryCounts();
    } catch (e) {
      if (mounted && _users.isEmpty) {
        setState(() => _error = userErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  Future<void> _updateStatus(String userId, bool suspend) async {
    try {
      await AdminApiService.updateUserStatus(userId, {'is_suspended': suspend});
      _load();
      _snack(suspend ? 'User suspended' : 'User activated',
          suspend ? context.warningColor : context.successColor);
    } catch (e) {
      _snack(e.toString(), context.errorColor);
    }
  }

  Future<void> _loadSummaryCounts() async {
    try {
      final allRes = await AdminApiService.getUsers(page: 1);
      final verifiedRes =
          await AdminApiService.getUsers(page: 1, kycStatus: 'verified');
      final pendingRes =
          await AdminApiService.getUsers(page: 1, kycStatus: 'pending');
      final rejectedRes =
          await AdminApiService.getUsers(page: 1, kycStatus: 'rejected');
      if (!mounted) return;
      setState(() {
        _totalUsers = allRes['meta']?['total'] ?? 0;
        _verifiedCount = verifiedRes['meta']?['total'] ?? 0;
        _pendingCount = pendingRes['meta']?['total'] ?? 0;
        _rejectedCount = rejectedRes['meta']?['total'] ?? 0;
      });
    } catch (_) {
      // Summary counts are best-effort; ignore failures silently.
    }
  }

  Future<void> _viewUser(Map<String, dynamic> user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.onSurface.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                CircleAvatar(
                  backgroundColor: context.onSurface,
                  radius: 28,
                  child: Text(
                    (user['first_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        color: context.background,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['first_name']} ${user['last_name']}',
                        softWrap: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: context.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user['username']}',
                        softWrap: true,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _detailRow('Phone', user['phone'] ?? '-'),
              _detailRow('Email', user['email'] ?? '-'),
              _detailRow('Role', user['role'] ?? '-'),
              _detailRow('KYC Status', user['kyc_status'] ?? '-'),
              _detailRow('Wallet Balance',
                  'FARM ${user['balance']?.toString() ?? '0'}'),
              _detailRow('Status',
                  user['is_suspended'] == true ? 'Suspended' : 'Active'),
              _detailRow('Joined',
                  (user['created_at'] ?? '').toString().substring(0, 10)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user['is_suspended'] == true
                          ? context.successColor
                          : context.warningColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: Icon(
                        user['is_suspended'] == true
                            ? Icons.check_circle_rounded
                            : Icons.block_rounded,
                        size: 18),
                    label: Text(
                        user['is_suspended'] == true ? 'Activate' : 'Suspend'),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateStatus(user['id'], user['is_suspended'] != true);
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: context.onSurface,
                      onPressed: widget.onGoBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Users Management',
                            style: GoogleFonts.plusJakartaSans(
                                color: context.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                            'Browse users, review KYC and manage account status.',
                            style: GoogleFonts.plusJakartaSans(
                                color: context.onSurface.withValues(alpha: 0.6),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: context.onSurface.withValues(alpha: 0.12)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.filter_list_rounded,
                        color: context.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _users.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : _error != null && _users.isEmpty
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(color: context.onSurface)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 0),
                            children: [
                              _searchBar(cardColor),
                              const SizedBox(height: 12),
                              _filterChips(cardColor, accent),
                              const SizedBox(height: 24),
                              _summaryCards(cardColor, accent),
                              const SizedBox(height: 24),
                              ..._users
                                  .map((u) => _userCard(u, cardColor, accent))
                                  .toList(),
                              _paginationBar(cardColor),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(Color cardColor) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.onSurface.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: context.onSurface),
          decoration: InputDecoration(
            hintText: 'Search users by name, phone, email...',
            hintStyle:
                TextStyle(color: context.onSurface.withValues(alpha: 0.54)),
            prefixIcon: Icon(Icons.search_rounded,
                color: context.onSurface.withValues(alpha: 0.7)),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: context.onSurface.withValues(alpha: 0.7)),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _search = '';
                        _page = 1;
                      });
                      _load();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (v) {
            setState(() {
              _search = v;
              _page = 1;
            });
            _load();
          },
        ),
      );

  Widget _filterChips(Color cardColor, Color accent) => Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            const SizedBox(width: 4),
            for (final f in ['all', 'none', 'pending', 'verified', 'rejected'])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(f == 'all' ? 'All Users' : f.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _filter == f
                              ? context.onSurface
                              : context.onSurface.withValues(alpha: 0.7))),
                  selected: _filter == f,
                  selectedColor: AppTheme.accent,
                  backgroundColor: cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (_) {
                    setState(() {
                      _filter = f;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      );

  Widget _summaryCards(Color cardColor, Color accent) => Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _summaryCard(
                      'Total Users', '$_totalUsers', cardColor, accent, () {
                setState(() {
                  _filter = 'all';
                  _page = 1;
                });
                _load();
              })),
              const SizedBox(width: 14),
              Expanded(
                  child: _summaryCard(
                      'Verified KYC', '$_verifiedCount', cardColor, accent, () {
                setState(() {
                  _filter = 'verified';
                  _page = 1;
                });
                _load();
              })),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _summaryCard(
                      'Pending KYC', '$_pendingCount', cardColor, accent, () {
                setState(() {
                  _filter = 'pending';
                  _page = 1;
                });
                _load();
              })),
              const SizedBox(width: 14),
              Expanded(
                  child: _summaryCard(
                      'Rejected KYC', '$_rejectedCount', cardColor, accent, () {
                setState(() {
                  _filter = 'rejected';
                  _page = 1;
                });
                _load();
              })),
            ],
          ),
        ],
      );

  Widget _summaryCard(String title, String value, Color cardColor, Color accent,
      [VoidCallback? onTap]) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.onSurface.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Compared to last month',
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface.withValues(alpha: 0.38),
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> u, Color cardColor, Color accent) {
    final firstName = u['first_name']?.toString().trim() ?? '';
    final lastName = u['last_name']?.toString().trim() ?? '';
    final username = u['username']?.toString().trim() ?? '';
    final displayName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
    final visibleName = displayName.isNotEmpty
        ? displayName
        : username.isNotEmpty
            ? '@$username'
            : 'Unknown user';
    final initial = firstName.isNotEmpty
        ? firstName[0]
        : username.isNotEmpty
            ? username[0]
            : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.onSurface.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: accent,
          child: Text(initial.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                  color: context.background,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(visibleName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
                color: context.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.25)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(u['email'] ?? '-',
                style: GoogleFonts.plusJakartaSans(
                    color: context.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              runSpacing: 6,
              spacing: 6,
              children: [
                _tag(u['kyc_status'] ?? 'none', _kycColor(u['kyc_status'])),
                if (u['is_suspended'] == true)
                  _tag('SUSPENDED', context.errorColor),
              ],
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                'FARM ${double.tryParse(u['balance']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0'}',
                style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _viewUser(u),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withAlpha((0.18 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('View',
                    style: GoogleFonts.plusJakartaSans(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginationBar(Color cardColor) {
    final lastPage = (_total / 20).ceil();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
            child: Text('← Prev'),
          ),
          Text('$_page / $lastPage',
              style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: _page < lastPage
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
            child: Text('Next →'),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withAlpha((0.14 * 255).round()),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface.withValues(alpha: 0.54),
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Color _kycColor(String? s) {
    switch (s) {
      case 'verified':
        return context.successColor;
      case 'pending':
        return context.warningColor;
      case 'rejected':
        return context.errorColor;
      default:
        return context.textSecondary;
    }
  }
}
