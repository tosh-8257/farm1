import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '/widgets/common/back_chevron.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/utils/user_error_message.dart';

enum _SupportMediaSource {
  galleryPhoto,
  galleryVideo,
  cameraPhoto,
  cameraVideo
}

class LiveChatPageWidget extends StatefulWidget {
  const LiveChatPageWidget({super.key});

  @override
  State<LiveChatPageWidget> createState() => _LiveChatPageWidgetState();
}

class _LiveChatPageWidgetState extends State<LiveChatPageWidget> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, FocusNode> _replyFocusNodes = {};
  List<Map<String, dynamic>> _tickets = [];
  bool _sending = false;
  String? _sendingReplyTicketId;
  bool _loadingTickets = true;
  String? _ticketsError;
  Timer? _refreshTimer;
  XFile? _newEnquiryAttachment;

  static const int _maxAttachmentBytes = 20 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loadingTickets && !_sending && _sendingReplyTicketId == null) {
        _loadTickets(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subjectController.dispose();
    _messageController.dispose();
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
        _loadingTickets = true;
        _ticketsError = null;
      });
    }
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/support/tickets',
      );
      final rows = response['data'];
      if (rows is! List) {
        throw const FormatException('Invalid support enquiry response');
      }
      if (!mounted) return;
      setState(() {
        _tickets = rows.whereType<Map<String, dynamic>>().toList();
        _loadingTickets = false;
        _ticketsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketsError = userErrorMessage(error);
        _loadingTickets = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    final attachment = _newEnquiryAttachment;
    if (subject.isEmpty || (message.isEmpty && attachment == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a subject and message or attach a photo/video'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.request(
        method: 'POST',
        path: '/support/tickets',
        timeoutSeconds: attachment == null ? 20 : 90,
        body: {
          'subject': subject,
          'message': message,
          if (attachment != null) ...(await _attachmentPayload(attachment)),
        },
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      setState(() => _newEnquiryAttachment = null);
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Your enquiry has been sent to support.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send enquiry: ${userErrorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Map<String, dynamic>> _attachmentPayload(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxAttachmentBytes) {
      throw Exception('Choose a photo or video smaller than 20 MB.');
    }
    final mimeType = _mimeTypeFor(file);
    if (mimeType == null) {
      throw Exception('Choose a supported photo or video file.');
    }
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Images must be no larger than 5 MB.');
      }
      final extension = switch (mimeType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final urls = await ApiService.uploadImages(
        files: [bytes],
        filenames: ['support-attachment.$extension'],
        mimeTypes: [mimeType],
      );
      return {
        'attachmentUrl': urls.single,
        'attachmentMimeType': mimeType,
      };
    }
    return {
      'attachmentBase64': base64Encode(bytes),
      'attachmentMimeType': mimeType,
    };
  }

  String? _mimeTypeFor(XFile file) {
    const supported = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'image/heic',
      'image/heif',
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'video/x-m4v',
    };
    final detected = file.mimeType?.toLowerCase();
    if (detected != null && supported.contains(detected)) return detected;
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => null,
    };
  }

  Future<XFile?> _pickMedia() async {
    final choice = await showModalBottomSheet<_SupportMediaSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo from gallery'),
              onTap: () => Navigator.pop(
                sheetContext,
                _SupportMediaSource.galleryPhoto,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Choose video from gallery'),
              onTap: () => Navigator.pop(
                sheetContext,
                _SupportMediaSource.galleryVideo,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                _SupportMediaSource.cameraPhoto,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record a video'),
              onTap: () => Navigator.pop(
                sheetContext,
                _SupportMediaSource.cameraVideo,
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;

    final isVideo = choice == _SupportMediaSource.galleryVideo ||
        choice == _SupportMediaSource.cameraVideo;
    final source = choice == _SupportMediaSource.galleryPhoto ||
            choice == _SupportMediaSource.galleryVideo
        ? ImageSource.gallery
        : ImageSource.camera;
    final file = isVideo
        ? await _imagePicker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 2),
          )
        : await _imagePicker.pickImage(
            source: source,
            imageQuality: 85,
            maxWidth: 1920,
          );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxAttachmentBytes) {
      throw Exception('Choose a photo or video smaller than 20 MB.');
    }
    if (_mimeTypeFor(file) == null) {
      throw Exception('Choose a supported photo or video file.');
    }
    return file;
  }

  Future<void> _chooseEnquiryAttachment() async {
    try {
      final file = await _pickMedia();
      if (mounted && file != null) {
        setState(() => _newEnquiryAttachment = file);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach media: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  Widget _buildAttachmentPreview(dynamic rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return const SizedBox.shrink();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com') {
      return const Text('Attachment unavailable');
    }
    final isVideo = uri.path.contains('/video/upload/');
    if (isVideo) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _openVideo(uri),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Open attached video'),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                rawUrl,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load this photo.'),
                ),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            rawUrl,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Text('Could not load photo'),
          ),
        ),
      ),
    );
  }

  Future<void> _openVideo(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this video.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open this video: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  TextEditingController _replyControllerFor(String ticketId) =>
      _replyControllers.putIfAbsent(ticketId, TextEditingController.new);

  FocusNode _replyFocusNodeFor(String ticketId) =>
      _replyFocusNodes.putIfAbsent(ticketId, FocusNode.new);

  Future<bool> _replyToTicket(String ticketId, {XFile? attachment}) async {
    final controller = _replyControllerFor(ticketId);
    final message = controller.text.trim();
    if (message.isEmpty && attachment == null) return false;

    setState(() => _sendingReplyTicketId = ticketId);
    try {
      await ApiService.request(
        method: 'POST',
        path: '/support/tickets/$ticketId/reply',
        timeoutSeconds: attachment == null ? 20 : 90,
        body: {
          'message': message,
          if (attachment != null) ...(await _attachmentPayload(attachment)),
        },
      );
      controller.clear();
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your reply has been sent.')),
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
      if (mounted) setState(() => _sendingReplyTicketId = null);
    }
  }

  Future<void> _openReplyComposer(String ticketId) async {
    final controller = _replyControllerFor(ticketId);
    final focusNode = _replyFocusNodeFor(ticketId);
    XFile? selectedAttachment;

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
                  'Reply to support',
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
                    hintText: 'Write your message',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedAttachment != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _mimeTypeFor(selectedAttachment!)!.startsWith('video/')
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                    ),
                    title: Text(
                      selectedAttachment!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: () =>
                          setSheetState(() => selectedAttachment = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            try {
                              final file = await _pickMedia();
                              if (file != null && sheetContext.mounted) {
                                setSheetState(() => selectedAttachment = file);
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Could not attach media: ${userErrorMessage(error)}'),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add photo or video'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            setSheetState(() => isSending = true);
                            final sent = await _replyToTicket(ticketId,
                                attachment: selectedAttachment);
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

  String _value(dynamic value, [String fallback = '']) =>
      value is String && value.isNotEmpty ? value : fallback;

  String _dateTimeValue(dynamic value) {
    if (value is! String) return '';
    final dateTime = DateTime.tryParse(value);
    return dateTime == null
        ? ''
        : dateTime.toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        leading: const BackChevron(),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        title: const Text('Live Chat'),
        actions: [
          IconButton(
            tooltip: 'Refresh enquiries',
            onPressed: _loadingTickets ? null : _loadTickets,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: theme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send an enquiry to our support team. You can see replies here.',
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          TextField(
            controller: _messageController,
            minLines: 4,
            maxLines: 8,
            maxLength: 5000,
            decoration: InputDecoration(
              labelText: 'Your enquiry',
              hintText: 'Type your message here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_newEnquiryAttachment != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _mimeTypeFor(_newEnquiryAttachment!)!.startsWith('video/')
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
              ),
              title: Text(
                _newEnquiryAttachment!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Remove attachment',
                onPressed: _sending
                    ? null
                    : () => setState(() => _newEnquiryAttachment = null),
                icon: const Icon(Icons.close),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _sending ? null : _chooseEnquiryAttachment,
              icon: const Icon(Icons.attach_file),
              label: const Text('Add photo or video'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send to Support'),
            ),
          ),
          const SizedBox(height: 24),
          Text('My enquiries', style: theme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingTickets)
            const Center(child: CircularProgressIndicator())
          else if (_ticketsError != null && _tickets.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not load your enquiries: $_ticketsError'),
                TextButton(
                  onPressed: _loadTickets,
                  child: const Text('Try again'),
                ),
              ],
            )
          else if (_tickets.isEmpty)
            const Text('You have not sent any enquiries yet.')
          else ...[
            if (_ticketsError != null)
              TextButton(
                onPressed: _loadTickets,
                child: Text('Could not refresh enquiries: $_ticketsError'),
              ),
            ..._tickets.map((ticket) {
              final replies = ticket['support_messages'];
              return Card(
                child: ExpansionTile(
                  title: Text(_value(ticket['subject'], 'Enquiry')),
                  subtitle: Text(_value(ticket['status'], 'open')),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'You',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text([
                        _dateTimeValue(ticket['created_at']),
                        _value(ticket['message']),
                      ].where((part) => part.isNotEmpty).join('\n')),
                      dense: true,
                    ),
                    if (replies is List)
                      ...replies.whereType<Map<String, dynamic>>().map(
                        (reply) {
                          final sender = reply['users'];
                          final senderRole = sender is Map<String, dynamic>
                              ? _value(sender['role']).toLowerCase()
                              : '';
                          final senderName = sender is Map<String, dynamic>
                              ? [
                                  _value(sender['first_name']),
                                  _value(sender['last_name']),
                                ].where((part) => part.isNotEmpty).join(' ')
                              : '';
                          final senderDisplayName = senderName.isNotEmpty
                              ? senderName
                              : sender is Map<String, dynamic>
                                  ? _value(sender['username'])
                                  : '';
                          final senderLabel = senderRole.contains('admin')
                              ? 'Support${senderDisplayName.isEmpty ? '' : ' · $senderDisplayName'}'
                              : 'You';
                          final sentAt = _dateTimeValue(reply['created_at']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_value(reply['message']).isNotEmpty)
                                  Text(_value(reply['message'])),
                                _buildAttachmentPreview(
                                  reply['attachment_url'],
                                ),
                              ],
                            ),
                            subtitle: Text(
                              [senderLabel, sentAt]
                                  .where((part) => part.isNotEmpty)
                                  .join(' · '),
                            ),
                          );
                        },
                      ),
                    const Divider(height: 24),
                    Semantics(
                      button: true,
                      label: 'Reply to support',
                      child: InkWell(
                        onTap: _value(ticket['id']).isEmpty ||
                                _sendingReplyTicketId == _value(ticket['id'])
                            ? null
                            : () => _openReplyComposer(_value(ticket['id'])),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Reply to support',
                            border: OutlineInputBorder(),
                          ),
                          child: const SizedBox(height: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
