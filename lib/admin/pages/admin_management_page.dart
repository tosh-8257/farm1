import 'package:flutter/material.dart';

import '../../pages/superadmin/add_admin_page.dart';
import '../services/admin_api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  bool _loading = true;
  String? _error;
  String? _busyAdminId;
  List<Map<String, dynamic>> _admins = [];

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await AdminApiService.getAdmins();
      final data = response['data'];
      _admins = data is List
          ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
    } catch (error) {
      _error = userErrorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAdmin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddAdminPage()),
    );
    if (mounted) await _loadAdmins();
  }

  Future<void> _setStatus(
    Map<String, dynamic> admin,
    String action,
  ) async {
    final adminId = admin['id']?.toString();
    if (adminId == null || adminId.isEmpty) return;

    setState(() => _busyAdminId = adminId);
    try {
      final response = await AdminApiService.setAdminStatus(adminId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message']?.toString() ?? 'Updated')),
        );
      }
      await _loadAdmins();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAdminId = null);
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    final adminId = admin['id']?.toString();
    if (adminId == null || adminId.isEmpty) return;
    final name =
        '${admin['first_name'] ?? ''} ${admin['last_name'] ?? ''}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete admin?'),
        content: Text(
          'Delete ${name.isEmpty ? 'this admin' : name}? Their access will be revoked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyAdminId = adminId);
    try {
      final response = await AdminApiService.deleteAdmin(adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response['message']?.toString() ?? 'Admin deleted'),
          ),
        );
      }
      await _loadAdmins();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAdminId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Admin Management'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAdmins,
            tooltip: 'Refresh admins',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAdmin,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create admin'),
      ),
      body: _loading && _admins.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadAdmins,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _admins.isEmpty
                  ? const Center(child: Text('No admins found.'))
                  : RefreshIndicator(
                      onRefresh: _loadAdmins,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: _admins.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final admin = _admins[index];
                          final adminId = admin['id']?.toString();
                          final isBusy = adminId == _busyAdminId;
                          final isSuspended =
                              admin['is_suspended'] == true ||
                                  admin['is_active'] != true;
                          final name =
                              '${admin['first_name'] ?? ''} ${admin['last_name'] ?? ''}'
                                  .trim();

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.admin_panel_settings),
                                    ),
                                    title: Text(
                                      name.isEmpty
                                          ? admin['username']?.toString() ??
                                              'Admin'
                                          : name,
                                    ),
                                    subtitle: Text([
                                      if (admin['username'] != null)
                                        '@${admin['username']}',
                                      if (admin['email'] != null)
                                        admin['email'].toString(),
                                      if (admin['phone'] != null)
                                        admin['phone'].toString(),
                                    ].join('\n')),
                                    trailing: Chip(
                                      label: Text(
                                        isSuspended ? 'SUSPENDED' : 'ACTIVE',
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: isBusy
                                            ? null
                                            : () => _setStatus(
                                                  admin,
                                                  isSuspended
                                                      ? 'approve'
                                                      : 'suspend',
                                                ),
                                        icon: Icon(
                                          isSuspended
                                              ? Icons.check_circle_outline
                                              : Icons.block,
                                        ),
                                        label: Text(
                                          isSuspended ? 'Approve' : 'Suspend',
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: isBusy
                                            ? null
                                            : () => _deleteAdmin(admin),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
