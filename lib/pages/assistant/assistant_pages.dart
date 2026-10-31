import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/ai_api.dart';
import '/backend/services/api_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_input.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/travel/travel_pages.dart';
import '/pages/agent_payments/agent_payments_pages.dart';

const _actionLabels = {
  'pending': 'Waiting for you',
  'processing': 'Processing',
  'executed': 'Sent',
  'rejected': 'Rejected',
  'expired': 'Expired',
  'cancelled': 'Cancelled',
  'failed': 'Failed',
};

/// Confirms a pending AI payment with the transaction PIN. Returns true when sent.
Future<bool> confirmAiPayment(BuildContext c, Map<String, dynamic> a) async {
  final pin = await confirmWithPin(c,
      title: 'Confirm payment',
      message: 'Send ${money(a['amount'])} to ${a['recipient_identifier']}?'
          '${a['description'] != null ? '\n"${a['description']}"' : ''}\n\nMkulima proposed this. Only your PIN sends it.');
  if (pin == null || !c.mounted) return false;
  final r = await runBusy(c, () => AiApi.confirm('${a['id']}', pin), success: 'Payment sent');
  return r != null;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.a, this.onChanged);
  final Map<String, dynamic> a;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext c) {
    final status = '${a['status']}';
    final pending = status == 'pending';
    if (a['action'] == 'book_flight') return _flightCard(c, status, pending);
    if (a['action'] == 'pay_intent') return _intentCard(c, status, pending);
    if (a['action'] == 'book_hotel') return _hotelCard(c, status, pending);
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Payment request',
                  style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
          StatusChip(_actionLabels[status] ?? status, filled: status == 'executed'),
        ]),
        const SizedBox(height: 8),
        KeyValue('Amount', money(a['amount'])),
        KeyValue('To', '${a['recipient_identifier']}'),
        if (a['description'] != null) KeyValue('Note', '${a['description']}'),
        if (a['transaction_ref'] != null) KeyValue('Reference', '${a['transaction_ref']}'),
        if (pending && a['failure_reason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Last attempt: ${a['failure_reason']}', style: TextStyle(color: mutedColor(c), fontSize: 12)),
          ),
        if (pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  final ok = await runBusy(c, () => AiApi.reject('${a['id']}').then((_) => true), success: 'Rejected');
                  if (ok == true) onChanged();
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: primaryButtonStyle(c),
                onPressed: () async {
                  if (await confirmAiPayment(c, a)) onChanged();
                },
                child: const Text('Confirm with PIN'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Confirms a Mkulima hotel proposal in chat. The server re-prices, checks the PIN and books.
Future<bool> confirmAiHotel(BuildContext c, Map<String, dynamic> a) async {
  final p = (a['payload'] as Map?) ?? const {};
  final pin = await confirmWithPin(c,
      title: 'Confirm hotel booking',
      message: 'Book ${a['recipient_identifier']} (${p['checkin'] ?? ''} to ${p['checkout'] ?? ''}) for ${money(a['amount'])}?'
          '${p['refundable'] == false ? '\nThis rate is non-refundable.' : ''}'
          '${p['sandbox'] == true ? '\nSandbox booking (test only).' : ''}'
          '\n\nGuest details come from your profile. Only your PIN books it.');
  if (pin == null || !c.mounted) return false;
  final r = await runBusy(c, () => AiApi.confirm('${a['id']}', pin), success: 'Booking processed');
  return r != null;
}

/// Mkulima chat. Disabled state when the server has no AI provider configured.
extension on _ActionCard {
  Widget _hotelCard(BuildContext c, String status, bool pending) {
    final p = (a['payload'] as Map?) ?? const {};
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Hotel booking request', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
          StatusChip(status == 'executed' ? 'Booked' : (_actionLabels[status] ?? status), filled: status == 'executed'),
        ]),
        const SizedBox(height: 8),
        KeyValue('Hotel', '${a['recipient_identifier']}'),
        if (p['room_name'] != null) KeyValue('Room', '${p['room_name']}'),
        if (p['checkin'] != null) KeyValue('Dates', '${p['checkin']} to ${p['checkout']}'),
        KeyValue('Price', money(a['amount'])),
        if (p['refundable'] != null) KeyValue('Refundable', p['refundable'] == true ? 'Yes' : 'No'),
        if (p['sandbox'] == true) KeyValue('Mode', 'Sandbox (test)'),
        if (a['transaction_ref'] != null) KeyValue('Confirmation', '${a['transaction_ref']}'),
        if (a['failure_reason'] != null && status != 'executed')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(status == 'failed' ? 'Failed: ${a['failure_reason']}' : 'Last attempt: ${a['failure_reason']}',
                style: TextStyle(color: mutedColor(c), fontSize: 12)),
          ),
        if (pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  final ok = await runBusy(c, () => AiApi.reject('${a['id']}').then((_) => true), success: 'Rejected');
                  if (ok == true) onChanged();
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: primaryButtonStyle(c),
                onPressed: () async {
                  if (await confirmAiHotel(c, a)) onChanged();
                },
                child: const Text('Book with PIN'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _flightCard(BuildContext c, String status, bool pending) {
    final offerId = '${(a['payload'] as Map?)?['offer_id'] ?? ''}';
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Flight booking request', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
          StatusChip(status == 'executed' ? 'Booked' : (_actionLabels[status] ?? status), filled: status == 'executed'),
        ]),
        const SizedBox(height: 8),
        KeyValue('Price', '${money(a['amount'])}'),
        if (a['description'] != null) KeyValue('Flight', '${a['description']}'),
        if (pending && offerId.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  final ok = await runBusy(c, () => AiApi.reject('${a['id']}').then((_) => true), success: 'Rejected');
                  if (ok == true) onChanged();
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: primaryButtonStyle(c),
                onPressed: () async {
                  await pushPage(c, TravelOfferPage(offerId: offerId, aiActionId: '${a['id']}'));
                  onChanged();
                },
                child: const Text('Review & book'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({super.key, this.conversationId});
  final String? conversationId;
  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = []; // {role, content} or {role:'action', action}
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool? _enabled;
  String? _error;
  String? _lastFailed;
  String? _lastLanguage; // language of the last confirmed voice message
  final _tts = FlutterTts();
  int? _speaking;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await AiApi.status();
      _enabled = s['enabled'] == true;
      if (_enabled! && _conversationId != null) {
        final conv = await AiApi.conversation(_conversationId!);
        _items
          ..clear()
          ..addAll(((conv['messages'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => {'role': '${m['role']}', 'content': '${m['content']}'}));
      }
    } catch (e) {
      _error = friendlyError(e);
    }
    if (mounted) setState(() => _loading = false);
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _voice() async {
    final v = await showVoiceInputSheet(context);
    if (v == null || !mounted) return; // cancelled: nothing is sent
    _lastLanguage = v.language;
    await _sendText(v.text, language: v.language, fromVoice: true);
  }

  Future<void> _readAloud(int i, String text) async {
    if (_speaking == i) {
      await _tts.stop();
      setState(() => _speaking = null);
      return;
    }
    final sw = (_lastLanguage ?? '').startsWith('sw');
    try {
      await _tts.setLanguage(sw ? 'sw-KE' : 'en-US');
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = null);
      });
      setState(() => _speaking = i);
      await _tts.speak(text.replaceAll(RegExp(r'[*_#`]'), ''));
    } catch (_) {
      if (mounted) {
        setState(() => _speaking = null);
        bizSnack(context, 'Read aloud is not available on this device');
      }
    }
  }

  Future<void> _send([String? retry]) => _sendText(retry);

  Future<void> _sendText(String? retry, {String? language, bool fromVoice = false}) async {
    final text = (retry ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      if (retry == null || fromVoice) {
        _items.add({'role': 'user', 'content': text, if (fromVoice) 'voice': true});
      }
      if (!fromVoice) _input.clear();
      _sending = true;
      _lastFailed = null;
    });
    _toBottom();
    try {
      final r = await AiApi.chat(text,
          conversationId: _conversationId, language: language ?? _lastLanguage);
      _conversationId = '${r['conversation_id']}';
      final msg = r['message'] is Map ? r['message'] as Map : const {};
      setState(() {
        _items.add({'role': 'assistant', 'content': '${msg['content'] ?? ''}'});
        for (final a in ((r['pending_actions'] as List?) ?? const []).whereType<Map>()) {
          _items.add({'role': 'action', 'action': Map<String, dynamic>.from(a)});
        }
      });
    } catch (e) {
      final lowBalance = e is ApiServiceException && e.statusCode == 402;
      setState(() {
        // Retrying can't help when the balance is too low; offer a top-up instead.
        _lastFailed = lowBalance ? null : text;
        _items.add({
          'role': 'error',
          'content': friendlyError(e),
          if (lowBalance) 'low_balance': true,
        });
      });
    }
    if (mounted) setState(() => _sending = false);
    _toBottom();
  }

  Widget _bubble(BuildContext c, Map<String, dynamic> m) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    final role = m['role'];
    if (role == 'action') {
      final a = m['action'] as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _ActionCard(a, () async {
          final list = await AiApi.actions();
          final fresh = list.firstWhere((x) => x['id'] == a['id'], orElse: () => a);
          if (mounted) setState(() => m['action'] = fresh);
        }),
      );
    }
    if (role == 'error') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.error_outline, size: 18, color: mutedColor(c)),
          const SizedBox(width: 6),
          Expanded(child: Text('${m['content']}', style: TextStyle(color: mutedColor(c)))),
          if (m['low_balance'] == true)
            TextButton(
                key: const ValueKey('mkulima-top-up'),
                onPressed: () => c.push('/depositpage'),
                child: Text('Top up', style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700))),
          if (_lastFailed != null && identical(m, _items.last))
            TextButton(
                onPressed: () {
                  setState(() => _items.removeLast());
                  _send(_lastFailed);
                },
                child: Text('Retry', style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final mine = role == 'user';
    final bg = mine ? (dark ? Colors.white : Colors.black) : cardColor(c);
    final fg = mine ? (dark ? Colors.black : Colors.white) : fgColor(c);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: '${m['content']}'));
          if (c.mounted) bizSnack(c, 'Copied');
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * 0.78),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: borderColor(c)),
          ),
          child: mine
              ? Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Text('${m['content']}', style: TextStyle(color: fg, height: 1.35)),
                  if (m['voice'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.mic, size: 12, color: fg.withValues(alpha: 0.7)),
                        Text(' voice, confirmed', style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
                      ]),
                    ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${m['content']}', style: TextStyle(color: fg, height: 1.35)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _readAloud(_items.indexOf(m), '${m['content']}'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_speaking == _items.indexOf(m) ? Icons.stop : Icons.volume_up_outlined,
                              size: 14, color: mutedColor(c)),
                          Text(_speaking == _items.indexOf(m) ? ' Stop' : ' Read aloud',
                              style: TextStyle(fontSize: 11, color: mutedColor(c))),
                        ]),
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _body(BuildContext c) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: BizMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Something went wrong',
              message: _error!,
              action: _init,
              actionLabel: 'Retry'));
    }
    if (_enabled != true) {
      return const Center(
          child: BizMessage(
              icon: Icons.smart_toy_outlined,
              title: 'Mkulima is not available yet',
              message: 'The assistant will appear here once it is switched on.'));
    }
    return Column(children: [
      Expanded(
        child: _items.isEmpty
            ? ListView(padding: const EdgeInsets.all(24), children: [
                const SizedBox(height: 40),
                const BizMessage(
                    icon: Icons.smart_toy_outlined,
                    title: 'Ask Mkulima',
                    message: 'Ask about your balance, recent transactions, investments, invoices or projects. '
                        'Mkulima can prepare a payment, but only you can send it with your PIN.'),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  for (final s in const ['What is my balance?', 'Show my last 5 transactions', 'How are my investments doing?'])
                    ActionChip(
                      label: Text(s, style: TextStyle(color: fgColor(c))),
                      backgroundColor: cardColor(c),
                      side: BorderSide(color: borderColor(c)),
                      onPressed: () => _send(s),
                    ),
                ]),
              ])
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _items.length + (_sending ? 1 : 0),
                itemBuilder: (c, i) => i == _items.length
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: mutedColor(c))),
                            const SizedBox(width: 8),
                            Text('Mkulima is thinking…', style: TextStyle(color: mutedColor(c))),
                          ]),
                        ),
                      )
                    : _bubble(c, _items[i]),
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor(c)))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(color: fgColor(c)),
              decoration: bizInput(c, 'Message Mkulima').copyWith(counterText: '', labelText: null, hintText: 'Message Mkulima'),
            ),
          ),
          IconButton(
            key: const ValueKey('mkulima-mic'),
            tooltip: 'Voice message',
            onPressed: _sending ? null : _voice,
            icon: Icon(Icons.mic_none_rounded, color: fgColor(c)),
          ),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: Icon(Icons.arrow_upward_rounded, color: fgColor(c)),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Mkulima',
        actions: [
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.history),
            onPressed: () => pushPage(context, const AssistantConversationsPage()),
          ),
          IconButton(
            tooltip: 'Payment settings',
            icon: const Icon(Icons.tune),
            onPressed: () => pushPage(context, const AssistantSettingsPage()),
          ),
        ],
        body: _body(context),
      );
}

class AssistantConversationsPage extends StatelessWidget {
  const AssistantConversationsPage({super.key});
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Chats',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: AiApi.conversations,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.chat_bubble_outline,
          emptyTitle: 'No chats yet',
          emptyMessage: 'Your conversations with Mkulima will appear here.',
          builder: (c, l, reload) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: l.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => BizTile(
              title: '${l[i]['title'] ?? 'Chat'}',
              subtitle: shortDate(l[i]['updated_at']),
              onTap: () => Navigator.of(c).pushReplacement(
                  MaterialPageRoute(builder: (_) => AssistantChatPage(conversationId: '${l[i]['id']}'))),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: mutedColor(c)),
                onPressed: () async {
                  if (!await confirmAction(c, title: 'Delete chat', message: 'Delete this conversation?', confirm: 'Delete')) return;
                  if (!c.mounted) return;
                  await runBusy(c, () => AiApi.deleteConversation('${l[i]['id']}'));
                  reload();
                },
              ),
            ),
          ),
        ),
      );
}

/// Spending permissions: caps, enable, revoke, plus pending requests and audit.
class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key});
  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
  final _key = GlobalKey<BizAsyncState<List<dynamic>>>();
  Future<List<dynamic>> _load() => Future.wait([AiApi.permissions(), AiApi.actions(status: 'pending')]);

  Future<void> _edit(BuildContext c, Map<String, dynamic> p) async {
    final perTx = TextEditingController(text: '${p['per_tx_cap'] ?? 0}');
    final daily = TextEditingController(text: '${p['daily_cap'] ?? 0}');
    final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow Mkulima payments'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Mkulima can only propose payments within these limits. Every payment still needs your PIN.'),
          const SizedBox(height: 12),
          TextField(controller: perTx, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: bizInput(ctx, 'Max per payment (FARM)')),
          const SizedBox(height: 10),
          TextField(controller: daily, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: bizInput(ctx, 'Max per day (FARM)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    final a = num.tryParse(perTx.text.trim()), d = num.tryParse(daily.text.trim());
    perTx.dispose();
    daily.dispose();
    if (ok != true || !c.mounted) return;
    if (a == null || d == null || a <= 0 || d < a) {
      bizSnack(c, 'Enter amounts above zero; the daily limit must be at least the per-payment limit.');
      return;
    }
    await runBusy(c, () => AiApi.savePermissions(enabled: true, perTxCap: a, dailyCap: d), success: 'Saved');
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Mkulima payments',
        actions: [
          IconButton(tooltip: 'Activity log', icon: const Icon(Icons.receipt_long_outlined), onPressed: () => pushPage(context, const AssistantAuditPage())),
        ],
        body: BizAsync<List<dynamic>>(
          key: _key,
          load: _load,
          builder: (c, r, reload) {
            final p = Map<String, dynamic>.from(r[0] as Map);
            final pending = (r[1] as List).cast<Map<String, dynamic>>();
            final on = p['enabled'] == true;
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('AI payments', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(on ? 'On' : 'Off', filled: on),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      on
                          ? 'Mkulima may prepare FARM payments within your limits. Nothing is sent until you confirm with your PIN.'
                          : 'Mkulima cannot prepare payments. It can still answer questions about your account.',
                      style: TextStyle(color: mutedColor(c))),
                  if (on) ...[
                    const SizedBox(height: 10),
                    KeyValue('Max per payment', money(p['per_tx_cap'])),
                    KeyValue('Max per day', money(p['daily_cap'])),
                    KeyValue('Used today', money(p['spent_today'])),
                    KeyValue('Above your limits', 'Refused. Every payment needs your PIN.'),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        style: primaryButtonStyle(c),
                        onPressed: () => _edit(c, p),
                        child: Text(on ? 'Change limits' : 'Turn on'),
                      ),
                    ),
                    if (on) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: secondaryButtonStyle(c),
                          onPressed: () async {
                            if (!await confirmAction(c,
                                title: 'Revoke AI payments',
                                message: 'Turn off AI payments and cancel all pending requests?',
                                confirm: 'Revoke')) return;
                            if (!c.mounted) return;
                            await runBusy(c, AiApi.revoke, success: 'AI payments revoked');
                            reload();
                          },
                          child: const Text('Revoke'),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              if (on) ...[
                const SizedBox(height: 20),
                Text('Spending categories', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                const SizedBox(height: 4),
                Text('Mkulima can only pay in the categories you leave on.', style: TextStyle(color: mutedColor(c), fontSize: 12)),
                const SizedBox(height: 8),
                BizCard(
                  child: Column(children: [
                    for (final cat in AiApi.spendCategories)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeThumbColor: fgColor(c),
                        title: Text(cat, style: TextStyle(color: fgColor(c))),
                        value: ((p['spend_categories'] as List?) ?? AiApi.spendCategories).contains(cat),
                        onChanged: (v) async {
                          final cur = List<String>.from((p['spend_categories'] as List?) ?? AiApi.spendCategories);
                          v ? cur.add(cat) : cur.remove(cat);
                          final r = await runBusy(c,
                              () => AiApi.savePermissions(enabled: true, perTxCap: p['per_tx_cap'] as num, dailyCap: p['daily_cap'] as num, categories: cur));
                          if (r != null) reload();
                        },
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              Text('Pending requests', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                Text('No payments waiting for you.', style: TextStyle(color: mutedColor(c)))
              else
                for (final a in pending) Padding(padding: const EdgeInsets.only(bottom: 8), child: _ActionCard(a, reload)),
            ]);
          },
        ),
      );
}

class AssistantAuditPage extends StatelessWidget {
  const AssistantAuditPage({super.key});
  static const _labels = {
    'tool_call': 'Looked up data',
    'action_proposed': 'Payment proposed',
    'action_executed': 'Payment sent',
    'action_failed': 'Payment failed',
    'action_rejected': 'Payment rejected',
    'permissions_updated': 'Limits changed',
    'permissions_revoked': 'AI payments revoked',
    'conversation_deleted': 'Chat deleted',
  };
  String _detail(Map<String, dynamic> e) {
    final d = e['details'] is Map ? e['details'] as Map : const {};
    if (d['tool'] != null) return '${d['tool']}'.replaceAll('_', ' ');
    if (d['amount'] != null) return '${money(d['amount'])}${d['recipient'] != null ? ' to ${d['recipient']}' : ''}';
    if (d['daily_cap'] != null) return 'Per payment ${money(d['per_tx_cap'])}, daily ${money(d['daily_cap'])}';
    if (d['reason'] != null) return '${d['reason']}';
    return '';
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Activity log',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: AiApi.audit,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'No activity yet',
          emptyMessage: 'Everything Mkulima does on your account is recorded here.',
          builder: (c, l, _) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: l.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => BizTile(
              title: _labels[l[i]['event']] ?? '${l[i]['event']}',
              subtitle: [_detail(l[i]), shortDate(l[i]['created_at'])].where((s) => s.isNotEmpty).join(' · '),
            ),
          ),
        ),
      );
}

extension on _ActionCard {
  Widget _intentCard(BuildContext c, String status, bool pending) {
    final intentId = '${(a['payload'] as Map?)?['payment_intent_id'] ?? ''}';
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Business payment', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
          StatusChip(_actionLabels[status] ?? status, filled: status == 'executed'),
        ]),
        const SizedBox(height: 8),
        KeyValue('Amount', '${money(a['amount'])}'),
        if (a['description'] != null) KeyValue('For', '${a['description']}'),
        if (a['transaction_ref'] != null) KeyValue('Reference', '${a['transaction_ref']}'),
        if (pending && a['failure_reason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Last attempt: ${a['failure_reason']}', style: TextStyle(color: mutedColor(c), fontSize: 12)),
          ),
        if (pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  final ok = await runBusy(c, () => AiApi.reject('${a['id']}').then((_) => true), success: 'Rejected');
                  if (ok == true) onChanged();
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: primaryButtonStyle(c),
                onPressed: () async {
                  final pin = await confirmWithPin(c,
                      title: 'Confirm payment',
                      message: 'Pay ${money(a['amount'])}${a['description'] != null ? ' for "${a['description']}"' : ''}?\n\nMkulima proposed this. Only your PIN sends it.');
                  if (pin == null || !c.mounted) return;
                  final r = await runBusy(c, () => AiApi.confirm('${a['id']}', pin), success: 'Payment sent');
                  if (r != null) onChanged();
                },
                child: const Text('Pay with PIN'),
              ),
            ),
          ]),
          if (intentId.isNotEmpty)
            TextButton(
              onPressed: () => pushPage(c, PayIntentPage(id: intentId)),
              child: Text('View request', style: TextStyle(color: mutedColor(c))),
            ),
        ],
      ]),
    );
  }
}
