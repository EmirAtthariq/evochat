import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_typing_indicator/simple_typing_indicator.dart';
import 'package:evochat/widgets/app_bar.dart';
import 'package:evochat/services/chat_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Model sederhana untuk satu pesan chat
class ChatMessage {
  String text;
  final bool isUser;
  final DateTime time;
  final bool isWelcomeMessage;
  String? id;
  String? feedback;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.isWelcomeMessage = false,
    this.id,
    this.feedback,
  }) : time = time ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final bool openHistoryOnStart;
  final String? initialConversationId;

  const ChatScreen({
    super.key,
    this.openHistoryOnStart = false,
    this.initialConversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  final _chatService = ChatService(baseUrl: 'http://192.168.56.1:3000');
  String? _conversationId;

  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _startNewChat();

    if (widget.initialConversationId != null) {
      _loadConversation(widget.initialConversationId!);
    } else if (widget.openHistoryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openHistory();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startNewChat() {
    setState(() {
      _conversationId = null;
      _messages = [
        ChatMessage(
          text: 'Halo! Saya adalah asisten EvoChat. Ada yang bisa saya bantu?',
          isUser: false,
          isWelcomeMessage: true,
        ),
      ];
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Gabungin _messages jadi daftar campuran: separator tanggal + bubble.
  /// Dihitung ulang tiap build, bukan disimpan sebagai state.
  List<Object> _buildItemsWithSeparators() {
    final items = <Object>[];
    DateTime? lastDate;

    for (final msg in _messages) {
      final msgDate = DateTime(msg.time.year, msg.time.month, msg.time.day);
      if (lastDate == null || msgDate != lastDate) {
        items.add(msgDate); // DateTime = penanda separator
        lastDate = msgDate;
      }
      items.add(msg);
    }
    return items;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Hari Ini';
    if (date == yesterday) return 'Kemarin';

    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  Future<void> _openHistory() async {
    setState(() => _isLoadingHistory = true);

    try {
      final conversations = await _chatService.fetchConversations();

      if (!mounted) return;

      setState(() => _isLoadingHistory = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => _HistorySheet(
          conversations: conversations,
          onSelect: (id) => _loadConversation(id, closeSheet: true),
          chatService: _chatService,
          currentConversationId: _conversationId, // baru
          onCurrentDeleted: _startNewChat, // baru
          
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat: $e')),
      );
    }
  }

  Future<void> _loadConversation(String conversationId, {bool closeSheet = false}) async {
    if (closeSheet) {
      Navigator.of(context).pop();
    }

    try {
      final apiMessages = await _chatService.fetchConversationMessages(conversationId);

      if (!mounted) return;

      setState(() {
        _conversationId = conversationId;
        _messages = apiMessages
            .map((m) => ChatMessage(
                  text: m.content,
                  isUser: m.role == 'user',
                  id: m.id,
                  feedback: m.feedback,
                  time: m.createdAt,
                ))
            .toList();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat percakapan: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final apiMessages = _messages
        .where((m) => !m.isWelcomeMessage)
        .map((m) => ApiMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
            ))
        .toList();

    int? assistantIndex;

    final newConvId = await _chatService.sendMessage(
      messages: apiMessages,
      conversationId: _conversationId,
      onFirstToken: (token) {
        setState(() {
          _isLoading = false;
          _isStreaming = true;
          _messages.add(ChatMessage(text: token, isUser: false));
          assistantIndex = _messages.length - 1;
        });
        _scrollToBottom();
      },
      onToken: (token) {
        if (assistantIndex == null) return;
        setState(() {
          _messages[assistantIndex!].text += token;
        });
        _scrollToBottom();
      },
      onDone: () async {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });

        if (_conversationId != null && assistantIndex != null) {
          try {
            final serverMessages = await _chatService.fetchConversationMessages(_conversationId!);
            if (!mounted) return;
            if (serverMessages.isNotEmpty) {
              final lastServerMsg = serverMessages.last;
              if (lastServerMsg.role == 'assistant') {
                setState(() {
                  _messages[assistantIndex!].id = lastServerMsg.id;
                });
              }
            }
          } catch (_) {
            // gagal ambil ID gak fatal
          }
        }
      },
      onError: (err) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          if (assistantIndex == null) {
            _messages.add(ChatMessage(
              text: 'Maaf, terjadi kesalahan: $err',
              isUser: false,
            ));
          }
        });
        _scrollToBottom();
      },
    );

    if (newConvId.isNotEmpty) {
      setState(() => _conversationId = newConvId);
    }
  }

  Future<void> _handleFeedback(int messageIndex, String feedback) async {
    final message = _messages[messageIndex];
    if (message.id == null) return;

    final newFeedback = message.feedback == feedback ? null : feedback;
    final previousFeedback = message.feedback;

    setState(() => message.feedback = newFeedback);

    try {
      await _chatService.sendFeedback(message.id!, newFeedback);
    } catch (e) {
      if (!mounted) return;
      setState(() => message.feedback = previousFeedback);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim feedback: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItemsWithSeparators();

    return Scaffold(
      appBar: EvoChatAppBar(
        title: 'EvoChat',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Percakapan',
            onPressed: _isLoadingHistory ? null : _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Percakapan Baru',
            onPressed: (_isLoading || _isStreaming) ? null : _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Helpdesk',
            onPressed: () => context.push('/helpdesk'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == items.length && _isLoading) {
                    return const _TypingIndicator();
                  }

                  final item = items[index];

                  if (item is DateTime) {
                    return _DateSeparator(label: _formatDateSeparator(item));
                  }

                  final message = item as ChatMessage;
                  final messageIndex = _messages.indexOf(message);

                  return _ChatBubble(
                    message: message,
                    onFeedback: (feedback) => _handleFeedback(messageIndex, feedback),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            _ChatInputBar(
              controller: _controller,
              onSend: _sendMessage,
              isLoading: _isLoading || _isStreaming,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pemisah tanggal, mirip WhatsApp — pill kecil di tengah
class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Bottom sheet daftar riwayat percakapan
class _HistorySheet extends StatefulWidget {
  final List<ConversationSummary> conversations;
  final void Function(String id) onSelect;
  final ChatService chatService;
  final String? currentConversationId; // baru
  final VoidCallback? onCurrentDeleted; // baru

  const _HistorySheet({
    required this.conversations,
    required this.onSelect,
    required this.chatService,
    this.currentConversationId,
    this.onCurrentDeleted,
    
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late List<ConversationSummary> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = List.from(widget.conversations);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Percakapan'),
        content: const Text('Yakin mau hapus percakapan ini? Aksi ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _handleDelete(ConversationSummary convo) {
    setState(() => _conversations.removeWhere((c) => c.id == convo.id));
        // kalau yang dihapus ini adalah percakapan yang lagi aktif di ChatScreen
    if (convo.id == widget.currentConversationId) {
      widget.onCurrentDeleted?.call();
    }
    _deleteFromServer(convo);
  }

  Future<void> _deleteFromServer(ConversationSummary convo) async {
    try {
      await widget.chatService.deleteConversation(convo.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
      setState(() => _conversations.add(convo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Riwayat Percakapan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            if (_conversations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Geser ke kiri untuk menghapus',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            if (_conversations.isEmpty)
              const Expanded(
                child: Center(child: Text('Belum ada riwayat percakapan.')),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return Dismissible(
                      key: ValueKey(convo.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) => _handleDelete(convo),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(convo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${convo.createdAt.day}/${convo.createdAt.month}/${convo.createdAt.year}',
                        ),
                        onTap: () => widget.onSelect(convo.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Widget bubble chat
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String feedback)? onFeedback;

  const _ChatBubble({required this.message, this.onFeedback});

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                isUser
                    ? Text(
                        message.text,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 15,
                        ),
                      )
                    : MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                          strong: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(message.time),
                  style: TextStyle(
                    fontSize: 11,
                    color: isUser
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          if (!isUser && !message.isWelcomeMessage && message.id != null && onFeedback != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      message.feedback == 'up' ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 16,
                      color: message.feedback == 'up' ? Colors.green : Colors.grey,
                    ),
                    onPressed: () => onFeedback!('up'),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      message.feedback == 'down' ? Icons.thumb_down : Icons.thumb_down_outlined,
                      size: 16,
                      color: message.feedback == 'down' ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => onFeedback!('down'),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Indikator "Sedang mengetik..."
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const SimpleTypingIndicator(
          dotColor: Colors.blue,
          dotSize: 7.0,
          spacing: 4.0,
          duration: Duration(milliseconds: 1000),
          speed: 1.0,
        ),
      ),
    );
  }
}

/// Bar input pesan di bagian bawah layar
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}