import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  runApp(const MyApp());
}

class ChatMessage {
  final String sender;
  final String text;
  final DateTime time;

  ChatMessage({required this.sender, required this.text, required this.time});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: (json['sender'] ?? 'anonymous').toString(),
      text: (json['text'] ?? '').toString(),
      time:
          DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WS Chat Demo',
      theme: ThemeData(useMaterial3: true),
      home: const UsernameScreen(),
    );
  }
}

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();

  void _continue() {
    final name =
        _controller.text.trim().isEmpty
            ? 'user${DateTime.now().millisecondsSinceEpoch % 1000}'
            : _controller.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(username: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter username')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Username'),
              onSubmitted: (_) => _continue(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _continue, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  const ChatScreen({super.key, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  WebSocketChannel? _channel;
  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _connected = false;
  String _statusText = 'Connecting...';

  final String wsUrl = 'ws://localhost:3000';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      setState(() {
        _connected = true;
        _statusText = 'Connected';
      });

      _channel!.stream.listen(
        (event) {
          try {
            final decoded =
                jsonDecode(event.toString()) as Map<String, dynamic>;
            if (decoded['type'] == 'chat') {
              final msg = ChatMessage.fromJson(decoded);
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          } catch (_) {}
        },
        onError: (_) {
          setState(() {
            _connected = false;
            _statusText = 'Disconnected';
          });
        },
        onDone: () {
          setState(() {
            _connected = false;
            _statusText = 'Disconnected';
          });
        },
      );
    } catch (e) {
      setState(() {
        _connected = false;
        _statusText = 'Failed to connect';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty || _channel == null) return;

    final payload = {
      "type": "chat",
      "sender": widget.username,
      "text": text,
      "time": DateTime.now().toIso8601String(),
    };

    _channel!.sink.add(jsonEncode(payload));
    _textController.clear();
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _avatarUrlFor(String username) {
    final u = Uri.encodeComponent(username);
    return 'https://api.dicebear.com/9.x/identicon/png?seed=$u';
  }

  Widget _avatar(String username) {
    final initials =
        username.trim().isEmpty
            ? '?'
            : username.trim().substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: Image.network(
          _avatarUrlFor(username),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          // пока грузится — показываем инициалы
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
          // если не загрузилось — тоже инициалы
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat (${widget.username})'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(
                  _connected ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: _connected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _connected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isMe = m.sender == widget.username;

                final bubble = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.sender,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(m.time),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(m.text, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        _avatar(m.sender),
                        const SizedBox(width: 10),
                      ],
                      Flexible(child: bubble),
                      if (isMe) ...[
                        const SizedBox(width: 10),
                        _avatar(m.sender),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type message...',
                        border: const OutlineInputBorder(),
                        enabled: _connected,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _connected ? _send : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
