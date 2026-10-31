import 'package:flutter/material.dart';

import '../services/admin_api_service.dart';
import '/utils/user_error_message.dart';

class SuperadminsManagementPage extends StatefulWidget {
  const SuperadminsManagementPage({super.key, required this.onGoBack});

  final VoidCallback onGoBack;

  @override
  State<SuperadminsManagementPage> createState() =>
      _SuperadminsManagementPageState();
}

class _SuperadminsManagementPageState extends State<SuperadminsManagementPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _superadmins = [];

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
      final response = await AdminApiService.getSuperadmins();
      final data = response['data'];
      if (data is List) {
        _superadmins = data;
      } else if (data is Map<String, dynamic>) {
        _superadmins =
            data['items'] is List ? data['items'] as List : <dynamic>[];
      }
    } catch (e) {
      _error = userErrorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmins'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onGoBack,
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading && _superadmins.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _superadmins.isEmpty
                  ? const Center(child: Text('No superadmins found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _superadmins.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user =
                            _superadmins[index] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            title: Text(user['name'] ??
                                user['first_name'] ??
                                'Superadmin'),
                            subtitle: Text(user['email'] ??
                                user['phone'] ??
                                'No contact info'),
                            trailing: const Chip(label: Text('SUPERADMIN')),
                          ),
                        );
                      },
                    ),
    );
  }
}
