import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/groups/data/models/group_chat_message.dart';
import 'package:study_sensei/features/groups/presentation/widgets/dojo_engagement_panel.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/models/dojo_pin.dart';
import 'package:study_sensei/features/groups/data/services/dojo_engagement_service.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhotoUrl;
  final bool isCurrentUserAdmin;
  final bool showEngagement;
  final Group? group;

  const GroupChatTab({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhotoUrl,
    required this.isCurrentUserAdmin,
    this.showEngagement = false,
    this.group,
  });

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isSending = false;
  GroupChatMessage? _editingMessage;
  GroupChatMessage? _replyingTo;
  String? _highlightedMessageId;
  Offset? _tapPosition;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages');

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    if (_editingMessage != null) {
      await _updateMessage(text);
      return;
    }

    setState(() => _isSending = true);

    try {
      await _messagesRef.add({
        'groupId': widget.groupId,
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'senderPhotoUrl': widget.currentUserPhotoUrl,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        if (_replyingTo != null) ...{
          'replyToMessageId': _replyingTo!.id,
          'replyToSenderId': _replyingTo!.senderId,
          'replyToSenderName': _replyingTo!.senderName,
          'replyPreview': _replyPreview(_replyingTo!.text),
        },
      });
      _messageController.clear();
      setState(() => _replyingTo = null);
      _scrollToLatestMessage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn’t send your message. Try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _updateMessage(String newText) async {
    final message = _editingMessage;
    if (message == null) return;

    setState(() => _isSending = true);

    try {
      await _messagesRef.doc(message.id).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });
      _cancelEditing();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn’t update your message. Try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(GroupChatMessage message) async {
    try {
      await _messagesRef.doc(message.id).delete();
      if (_editingMessage?.id == message.id) {
        _cancelEditing();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn’t delete your message. Try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToLatestMessage() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _startEditing(GroupChatMessage message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.text;
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  String _replyPreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.substring(0, normalized.length.clamp(0, 160));
  }

  void _startReply(GroupChatMessage message) {
    setState(() {
      _editingMessage = null;
      _replyingTo = message;
      _messageController.clear();
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  void _showMessageActions(
    BuildContext messageContext,
    GroupChatMessage message,
    bool isCurrentUser,
  ) async {
    final canEdit = isCurrentUser;
    final canDeleteForEveryone = isCurrentUser || widget.isCurrentUserAdmin;

    final overlay = Overlay.of(
      messageContext,
      rootOverlay: true,
    ).context.findRenderObject() as RenderBox?;
    final tapPosition = _tapPosition;

    RelativeRect position;
    if (tapPosition != null && overlay != null) {
      position = RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        overlay.size.width - tapPosition.dx,
        overlay.size.height - tapPosition.dy,
      );
    } else if (overlay != null) {
      position = RelativeRect.fromLTRB(
        overlay.size.width / 2,
        overlay.size.height / 2,
        overlay.size.width / 2,
        overlay.size.height / 2,
      );
    } else {
      position = const RelativeRect.fromLTRB(0, 0, 0, 0);
    }

    final entries = <PopupMenuEntry<String>>[];
    if (canEdit) {
      entries.add(
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
      );
    }
    if (canDeleteForEveryone) {
      entries.add(
        const PopupMenuItem(
          value: 'delete_for_everyone',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18),
              SizedBox(width: 12),
              Text('Delete for everyone'),
            ],
          ),
        ),
      );
    }
    if (widget.isCurrentUserAdmin && widget.group != null) {
      entries.add(const PopupMenuItem(value: 'pin', child: Text('Pin')));
    }

    final action = await showMenu<String>(
      context: messageContext,
      position: position,
      items: entries,
    );

    switch (action) {
      case 'edit':
        _startEditing(message);
        break;
      case 'delete_for_everyone':
        _confirmDeleteForEveryone(message);
        break;
      case 'pin':
        await DojoEngagementService().pin(
            group: widget.group!,
            type: DojoPinType.message,
            targetId: message.id,
            name: widget.currentUserName,
            preview: message.text);
        break;
      default:
        break;
    }
    _tapPosition = null;
  }

  Future<void> _confirmDeleteForEveryone(GroupChatMessage message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'This will delete the message for all members of the dojo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showEngagement) DojoEngagementPanel(dojoId: widget.groupId),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messagesRef
                .orderBy('sentAt', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Couldn’t load messages right now. Try reopening this Dojo.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'No messages yet. Say hello and start the conversation!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final messages = docs
                  .map(
                    (doc) => GroupChatMessage.fromDocument(doc, widget.groupId),
                  )
                  .toList();

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isCurrentUser =
                      message.senderId == widget.currentUserId;
                  return SwipeToReplyMessage(
                    onReply: () => _startReply(message),
                    onLongPressStart: (details) {
                      _tapPosition = details.globalPosition;
                    },
                    onLongPress: () => _showMessageActions(
                      context,
                      message,
                      isCurrentUser,
                    ),
                    child: DojoMessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      highlighted: _highlightedMessageId == message.id,
                      onReplyTap: () => _jumpToMessage(message, messages),
                    ),
                  );
                },
              );
            },
          ),
        ),
        DojoChatComposer(
            controller: _messageController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            isEditing: _editingMessage != null,
            replyingTo: _replyingTo,
            onSend: _sendMessage,
            onCancelEditing: _cancelEditing,
            onCancelReply: _cancelReply),
      ],
    );
  }

  void _jumpToMessage(
      GroupChatMessage message, List<GroupChatMessage> messages) {
    final target = message.replyToMessageId;
    final index = messages.indexWhere((m) => m.id == target);
    if (target == null || index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Original message isn't available.")));
      return;
    }
    _scrollController.animateTo(index * 96.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    setState(() => _highlightedMessageId = target);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _highlightedMessageId == target) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }
}

class SwipeToReplyMessage extends StatefulWidget {
  const SwipeToReplyMessage({
    super.key,
    required this.child,
    required this.onReply,
    this.onLongPressStart,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onReply;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressCallback? onLongPress;

  @override
  State<SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<SwipeToReplyMessage> {
  static const _threshold = 72.0;
  double _offset = 0;
  bool _triggered = false;

  void _update(DragUpdateDetails details) {
    if (_triggered) return;
    final offset = (_offset + details.delta.dx).clamp(-_threshold, _threshold);
    setState(() => _offset = offset);
    if (offset.abs() >= _threshold) {
      _triggered = true;
      HapticFeedback.selectionClick();
      widget.onReply();
    }
  }

  void _end([DragEndDetails? _]) {
    setState(() {
      _offset = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _end,
      onLongPressStart: widget.onLongPressStart,
      onLongPress: widget.onLongPress,
      child: Stack(
        alignment: _offset < 0 ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Opacity(
            opacity: progress,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.reply_rounded, color: AppColors.primaryLight),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset * .32, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class DojoMessageBubble extends StatelessWidget {
  final GroupChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onReplyTap;
  final bool highlighted;

  const DojoMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onReplyTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = isCurrentUser
        ? AppColors.primary.withValues(alpha: .24)
        : AppColors.surfaceElevated;
    const textColor = AppColors.textPrimary;
    final timeOfDay = TimeOfDay.fromDateTime(message.sentAt);
    final timeLabel =
        '${timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod}:${timeOfDay.minute.toString().padLeft(2, '0')} ${timeOfDay.period == DayPeriod.am ? 'AM' : 'PM'}';

    return Align(
      alignment: alignment,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .85),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
              color: highlighted
                  ? AppColors.primaryLight
                  : isCurrentUser
                      ? AppColors.borderActive
                      : AppColors.borderSubtle),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(isCurrentUser ? 16.0 : 4.0),
            bottomRight: Radius.circular(isCurrentUser ? 4.0 : 16.0),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToMessageId != null)
              GestureDetector(
                  onTap: onReplyTap,
                  child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color: AppColors.primaryLight, width: 2)),
                          color: AppColors.background.withValues(alpha: .22)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.replyToSenderName ?? 'Dojo member',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.primaryLight)),
                            Text(
                                message.replyPreview ??
                                    'Original message unavailable.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption)
                          ]))),
            if (!isCurrentUser)
              Text(
                message.senderName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            SelectableText(
              message.text,
              style: AppTypography.bodyLarge.copyWith(color: textColor),
            ),
            const SizedBox(height: 4.0),
            Text(
              timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            if (message.isEdited)
              Text(
                'Edited',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Presentation-only composer; sending/editing remain owned by GroupChatTab.
class DojoChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isSending;
  final bool isEditing;
  final GroupChatMessage? replyingTo;
  final VoidCallback onSend;
  final VoidCallback onCancelEditing;
  final VoidCallback? onCancelReply;
  const DojoChatComposer(
      {super.key,
      required this.controller,
      this.focusNode,
      this.isSending = false,
      this.isEditing = false,
      this.replyingTo,
      required this.onSend,
      required this.onCancelEditing,
      this.onCancelReply});
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isEditing)
              Row(children: [
                const Expanded(
                    child:
                        Text('Editing message', style: AppTypography.caption)),
                TextButton(
                    onPressed: isSending ? null : onCancelEditing,
                    child: const Text('Cancel')),
              ]),
            if (replyingTo != null)
              Row(children: [
                const Icon(Icons.reply_rounded,
                    size: 16, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Replying to ${replyingTo!.senderName}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.primaryLight)),
                      Text(replyingTo!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption)
                    ])),
                IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: isSending ? null : onCancelReply,
                    icon: const Icon(Icons.close))
              ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                  child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: MediaQuery.textScalerOf(context).scale(16) > 24
                          ? 2
                          : 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                          hintText: 'Message your Dojo',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)))),
              const SizedBox(width: 8),
              IconButton.filled(
                  tooltip: isEditing ? 'Save message' : 'Send message',
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(48, 48)),
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isEditing ? Icons.check : Icons.arrow_upward)),
            ]),
          ])));
}
