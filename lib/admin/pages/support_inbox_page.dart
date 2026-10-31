import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '/app_state.dart';
import '../services/admin_api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class SupportInboxPage extends StatefulWidget {
  const SupportInboxPage({super.key, this.onGoBack});

  final VoidCallback? onGoBack;

  @override
  State<SupportInboxPage> createState() => _SupportInboxPageState();
}

class _SupportInboxPageState extends State<SupportInboxPage> {
  List<Map<String, dynamic>> _tickets = [];
  final Set<String> _readTicketIds = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, FocusNode> _replyFocusNodes = {};
  bool _loading = true;
  String? _error;
  String? _sendingTicketId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loading && _sendingTicketId == null) {
        _loadTickets(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _replyFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedReadIds =
          preferences.getStringList(_readTicketStorageKey) ?? const [];
      final result = await AdminApiService.getSupportTickets();
      final rows = result['data'];
      if (rows is! List) {
        throw const FormatException('Invalid support ticket response');
      }
      if (!mounted) return;
      setState(() {
        _readTicketIds
          ..clear()
          ..addAll(storedReadIds);
        _tickets = rows.whereType<Map<String, dynamic>>().toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(error);
        _loading = false;
      });
    }
  }

  String get _readTicketStorageKey =>
      'support_read_tickets_${FFAppState().role}_${FFAppState().userId}';

  Map<String, List<Map<String, dynamic>>> _ticketsByUser() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final ticket in _tickets) {
      final user = ticket['users_support_tickets_user_idTousers'];
      final userId = user is Map ? _stringValue(user['id']) : '';
      final groupKey =
          userId.isNotEmpty ? userId : 'ticket:${_stringValue(ticket['id'])}';
      grouped.putIfAbsent(groupKey, () => []).add(ticket);
    }
    return grouped;
  }

  Future<void> _markFolderRead(List<Map<String, dynamic>> tickets) async {
    final ticketIds = tickets
        .map((ticket) => _stringValue(ticket['id']))
        .where((id) => id.isNotEmpty)
        .toList();
    if (ticketIds.every(_readTicketIds.contains)) return;

    setState(() => _readTicketIds.addAll(ticketIds));
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _readTicketStorageKey,
        _readTicketIds.toList(),
      );
      if (!saved) throw StateError('Could not save read enquiry state');
    } catch (error) {
      if (mounted) {
        setState(() => _readTicketIds.removeAll(ticketIds));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save read status: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  TextEditingController _controllerFor(String ticketId) =>
      _replyControllers.putIfAbsent(ticketId, TextEditingController.new);

  FocusNode _focusNodeFor(String ticketId) =>
      _replyFocusNodes.putIfAbsent(ticketId, FocusNode.new);

  Future<bool> _sendReply(String ticketId) async {
    final controller = _controllerFor(ticketId);
    final message = controller.text.trim();
    if (message.isEmpty) return false;

    setState(() => _sendingTicketId = ticketId);
    try {
      await AdminApiService.replyToSupportTicket(ticketId, message);
      controller.clear();
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent to the user.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reply: ${userErrorMessage(error)}')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingTicketId = null);
    }
  }

  Future<void> _openReplyComposer(String ticketId) async {
    final controller = _controllerFor(ticketId);
    final focusNode = _focusNodeFor(ticketId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var isSending = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              top: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reply to the user',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    hintText: 'Write your response',
                    border: OutlineInputBorder(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            setSheetState(() => isSending = true);
                            final sent = await _sendReply(ticketId);
                            if (sent && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            } else if (sheetContext.mounted) {
                              setSheetState(() => isSending = false);
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send reply'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _stringValue(dynamic value, [String fallback = '']) =>
      value is String && value.isNotEmpty ? value : fallback;

  String _dateTimeValue(dynamic value) {
    if (value is! String) return '';
    final dateTime = DateTime.tryParse(value);
    return dateTime == null
        ? ''
        : dateTime.toLocal().toString().split('.').first;
  }

  Widget _attachmentView(dynamic rawUrl) {
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.broken_image_outlined),
        title: Text('User attachment unavailable'),
        subtitle: Text('The attachment link is invalid.'),
      );
    }

    if (uri.path.toLowerCase().contains('/video/upload/')) {
      return Card(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.play_circle_outline),
          title: const Text('User attached a video'),
          subtitle: const Text('Tap to view the attached video'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _openAttachment(uri),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    uri.toString(),
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, __, ___) => _attachmentPlaceholder(
                      'Could not load the user photo',
                      'Use “Open photo” to view it directly.',
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                uri.toString(),
                width: 220,
                height: 180,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 220,
                    height: 180,
                    alignment: Alignment.center,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (_, __, ___) => _attachmentPlaceholder(
                  'Could not load the user photo',
                  'Use “Open photo” to view it directly.',
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _openAttachment(uri),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open photo'),
          ),
        ],
      ),
    );
  }

  Widget _attachmentPlaceholder(String title, String subtitle) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      );

  Future<void> _openAttachment(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the attachment.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the attachment: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  String _customerName(dynamic user) {
    if (user is! Map) return '';
    final fullName = [
      _stringValue(user['first_name']),
      _stringValue(user['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return fullName.isNotEmpty
        ? fullName
        : _stringValue(user['username'], 'User');
  }

  Widget _ticketCard(
    Map<String, dynamic> ticket,
    Map? user,
  ) {
    final id = _stringValue(ticket['id']);
    final messages = ticket['support_messages'];
    final customer = _customerName(user);
    final customerEmail = _stringValue(user?['email']);
    final customerPhone = _stringValue(user?['phone']);

    return ExpansionTile(
      key: PageStorageKey<String>('support-$id'),
      title: Text(
        _stringValue(ticket['subject'], 'Enquiry'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_stringValue(ticket['status'], 'open')}  ·  '
        '${_dateTimeValue(ticket['created_at'])}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'From ${customer.isEmpty ? 'User' : customer}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text([
            if (customerEmail.isNotEmpty) customerEmail,
            if (customerPhone.isNotEmpty) customerPhone,
            _dateTimeValue(ticket['created_at']),
          ].where((value) => value.isNotEmpty).join(' · ')),
          dense: true,
        ),
        if (_stringValue(ticket['message']).isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_stringValue(ticket['message'])),
          ),
        if (messages is List)
          ...messages.whereType<Map<String, dynamic>>().map((message) {
            final sender = message['users'];
            final senderRole = sender is Map<String, dynamic>
                ? _stringValue(sender['role']).toLowerCase()
                : '';
            final senderName = _customerName(sender);
            final senderLabel = senderRole.contains('admin')
                ? 'Admin response${senderName == 'User' ? '' : ' by $senderName'}'
                : 'User${senderName == 'User' ? '' : ' · $senderName'}';
            final sentAt = _dateTimeValue(message['created_at']);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stringValue(message['message']).isNotEmpty)
                    Text(_stringValue(message['message'])),
                  _attachmentView(message['attachment_url']),
                ],
              ),
              subtitle: Text(
                [senderLabel, sentAt]
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
              ),
            );
          }),
        const Divider(height: 24),
        Semantics(
          button: true,
          label: 'Reply to the user',
          child: InkWell(
            onTap: id.isEmpty || _sendingTicketId == id
                ? null
                : () => _openReplyComposer(id),
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Reply to the user',
                border: OutlineInputBorder(),
              ),
              child: const SizedBox(height: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _userFolder(
    String groupKey,
    List<Map<String, dynamic>> tickets,
  ) {
    final user = tickets.first['users_support_tickets_user_idTousers'];
    final customer = _customerName(user);
    final unreadCount = tickets
        .where((ticket) => !_readTicketIds.contains(_stringValue(ticket['id'])))
        .length;
    final sortedTickets = [...tickets]..sort((a, b) =>
        (_dateTimeValue(b['created_at']))
            .compareTo(_dateTimeValue(a['created_at'])));
    final latestSubject =
        _stringValue(sortedTickets.first['subject'], 'Support enquiry');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('support-user-$groupKey'),
        onExpansionChanged: (expanded) {
          if (expanded) unawaited(_markFolderRead(tickets));
        },
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline_rounded),
        ),
        title: Text(
          customer.isEmpty ? 'User' : customer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tickets.length} ${tickets.length == 1 ? 'enquiry' : 'enquiries'}'
          '  ·  $latestSubject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFCC3D3D),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          for (final ticket in sortedTickets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _ticketCard(
                ticket,
                ticket['users_support_tickets_user_idTousers'] as Map?,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: widget.onGoBack == null
            ? const BackChevron()
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: widget.onGoBack,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
        title: const Text('Support enquiries'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh enquiries',
            onPressed: _loading ? null : _loadTickets,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadTickets,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : _tickets.isEmpty
                  ? const Center(child: Text('No support enquiries yet.'))
                  : RefreshIndicator(
                      onRefresh: _loadTickets,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Could not refresh support enquiries: $_error',
                              ),
                            ),
                          ..._ticketsByUser().entries.map(
                                (entry) => _userFolder(entry.key, entry.value),
                              ),
                        ],
                      ),
                    ),
    );
  }
}
