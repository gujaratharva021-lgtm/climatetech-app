import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_trade_service.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService(ref.read(apiServiceProvider));
});

class _DisplayMessage {
  final String role;
  final String content;
  _DisplayMessage({required this.role, required this.content});
}

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_DisplayMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_DisplayMessage(role: 'user', content: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final history = _messages
          .take(_messages.length - 1)
          .map((m) => ChatTurn(role: m.role, content: m.content))
          .toList();
      final reply = await ref.read(aiServiceProvider).chat(message: text, history: history);
      if (!mounted) return;
      setState(() {
        _messages.add(_DisplayMessage(role: 'assistant', content: reply));
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_DisplayMessage(role: 'assistant', content: 'Sorry, I ran into an error: $e'));
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('AI Trade Assistant', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ask about listings, RFQs, orders, escrow, shipments, or general commodity trading.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DarkPalette.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _bubble(_messages[i]),
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: DarkPalette.leafGreen)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask the trade assistant...',
                      hintStyle: const TextStyle(color: DarkPalette.textMuted),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: DarkPalette.leafGreen),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_DisplayMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? DarkPalette.leafGreen.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13.5, height: 1.4)),
      ),
    );
  }
}
