import 'package:flutter/material.dart';

import '../services/admin_api_service.dart';
import '/utils/user_error_message.dart';

class SettingsManagementPage extends StatefulWidget {
  const SettingsManagementPage({required this.onGoBack, super.key});

  final VoidCallback onGoBack;

  @override
  State<SettingsManagementPage> createState() => _SettingsManagementPageState();
}

class _SettingsManagementPageState extends State<SettingsManagementPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _settings = [];

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
      final response = await AdminApiService.getSettings();
      final rows = response['data'];
      if (rows is! List) {
        throw const FormatException('Settings response was not a list.');
      }
      if (!mounted) return;
      setState(() {
        _settings = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editSetting(Map<String, dynamic> setting) async {
    final key = setting['setting_key']?.toString();
    if (key == null || key.isEmpty) return;
    final controller =
        TextEditingController(text: setting['setting_value']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update $key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    try {
      await AdminApiService.updateSetting(key, value);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update setting: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onGoBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh settings',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _settings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _settings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _settings.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No system settings found.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _settings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final setting = _settings[index];
                            final key =
                                setting['setting_key']?.toString() ?? 'Setting';
                            return Card(
                              child: ListTile(
                                title: Text(key),
                                subtitle: Text(
                                  setting['setting_value']?.toString() ?? '',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _editSetting(setting),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
