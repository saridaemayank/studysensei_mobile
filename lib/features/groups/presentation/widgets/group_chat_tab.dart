import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_sensei/features/groups/data/models/group_chat_message.dart';

class GroupChatTab extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhotoUrl;
  final bool isCurrentUserAdmin;

  const GroupChatTab({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhotoUrl,
    required this.isCurrentUserAdmin,
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
      });
      _messageController.clear();
      _scrollToLatestMessage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
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
          content: Text('Failed to edit message: $e'),
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
          content: Text('Failed to delete message: $e'),
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

  void _showMessageActions(
    BuildContext messageContext,
    GroupChatMessage message,
    bool isCurrentUser,
  ) async {
    final canEdit = isCurrentUser;
    final canDeleteForEveryone = isCurrentUser || widget.isCurrentUserAdmin;

    if (!canEdit && !canDeleteForEveryone) return;

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
                      'Unable to load messages right now.\n${snapshot.error}',
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
                  return GestureDetector(
                    onLongPressStart: (details) {
                      _tapPosition = details.globalPosition;
                    },
                    onLongPress: () => _showMessageActions(
                      context,
                      message,
                      isCurrentUser,
                    ),
                    child: _MessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_editingMessage != null)
                  Row(
                    children: [
                      const Icon(Icons.edit, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing message',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _isSending ? null : _cancelEditing,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(24.0)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _editingMessage == null
                                  ? Icons.send
                                  : Icons.check,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final GroupChatMessage message;
  final bool isCurrentUser;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = isCurrentUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
    final timeOfDay = TimeOfDay.fromDateTime(message.sentAt);
    final timeLabel =
        '${timeOfDay.hourOfPeriod}:${timeOfDay.minute.toString().padLeft(2, '0')} ${timeOfDay.period == DayPeriod.am ? 'AM' : 'PM'}';

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: backgroundColor,
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
            if (!isCurrentUser)
              Text(
                message.senderName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 4.0),
            Text(
              timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor.withOpacity(0.7),
              ),
            ),
            if (message.isEdited)
              Text(
                'Edited',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
