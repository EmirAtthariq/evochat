import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_typing_indicator/simple_typing_indicator.dart';
import 'package:evochat/widgets/app_bar.dart';
import 'package:evochat/services/chat_service.dart';

/// Model sederhana untuk satu pesan chat
class ChatMessage {
  String text; // dibuat non-final biar bisa diupdate saat streaming
  final bool isUser;
  final DateTime time;
  final bool isWelcomeMessage; // pesan sapaan, gak ikut dikirim ke API

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.isWelcomeMessage = false,
  }) : time = time ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final _chatService = ChatService(baseUrl: 'http://192.168.56.1:3000');
  String? _conversationId;

  bool _isLoading = false; // true = nunggu token pertama (typing indicator)
  bool _isStreaming = false; // true = lagi nerima token (input dikunci)

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Halo! Saya adalah asisten EvoChat. Ada yang bisa saya bantu?',
        isUser: false,
        isWelcomeMessage: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true; // munculin typing indicator dulu
    });
    _controller.clear();
    _scrollToBottom();

    // susun history buat dikirim (role user/assistant, tanpa pesan sapaan/kosong)
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
        // token pertama datang -> matiin typing indicator, munculin bubble
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
      onDone: () {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
      },
      onError: (err) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          // kalau belum ada bubble assistant sama sekali, tampilin pesan error sebagai bubble
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EvoChatAppBar(
        title: 'EvoChat',
        showBackButton: true,
        actions: [
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return const _TypingIndicator();
                  }
                  final message = _messages[index];
                  return _ChatBubble(message: message);
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

/// Widget bubble chat
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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