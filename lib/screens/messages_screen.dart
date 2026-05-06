import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dm.dart';
import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/player_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.league,
    required this.auth,
    required this.api,
    this.onChanged,
    this.refreshTick = 0,
  });

  final LeagueService league;
  final AuthService auth;
  final ApiClient api;
  final VoidCallback? onChanged;
  final int refreshTick;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Conversation> _conversations = [];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh(silent: false);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _refresh(silent: true);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);

    try {
      final conversations = await widget.league.conversations();
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
        _loading = false;
      });
      widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _refreshing = false;
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _newConversation() async {
    final players = await widget.league.players();
    if (!mounted) return;
    final options = players
        .where((player) => player.id != widget.auth.currentPlayer!.id)
        .toList();
    if (options.isEmpty) return;
    final player = await showAppOptionPicker<Player>(
      context: context,
      title: 'Nova poruka',
      selected: options.first,
      options: options,
      labelBuilder: (player) => player.fullName,
      leadingBuilder: (player) =>
          PlayerAvatar(player: player, api: widget.api, radius: 18),
    );
    if (player == null) return;
    final conversation = await widget.league.startConversation(player.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          league: widget.league,
          api: widget.api,
          auth: widget.auth,
          conversation: conversation,
          onChanged: widget.onChanged,
        ),
      ),
    );
    await _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayerId = widget.auth.currentPlayer!.id;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'messages-new-conversation-fab',
        onPressed: _newConversation,
        icon: const Icon(Icons.edit),
        label: const Text('Poruka'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refresh(silent: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(
                    'Dogovori meč, termin ili trening direktno sa igračima.',
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: .58),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_conversations.isEmpty)
                    const _EmptyInbox()
                  else
                    ..._conversations.map((conversation) {
                      final other = conversation.otherParticipant(
                        currentPlayerId,
                      );
                      return _ConversationCard(
                        conversation: conversation,
                        other: other,
                        api: widget.api,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                league: widget.league,
                                api: widget.api,
                                auth: widget.auth,
                                conversation: conversation,
                                onChanged: widget.onChanged,
                              ),
                            ),
                          );
                          await _refresh(silent: true);
                        },
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.other,
    required this.api,
    required this.onTap,
  });

  final Conversation conversation;
  final Player? other;
  final ApiClient api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: other == null
            ? const CircleAvatar(child: Icon(Icons.person))
            : PlayerAvatar(player: other!, api: api, radius: 26),
        title: Text(
          other?.fullName ?? 'Igrač',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          conversation.lastMessage ?? 'Još nema poruka.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: conversation.unreadCount > 0
            ? CircleAvatar(
                radius: 13,
                backgroundColor: AppTheme.court,
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.league,
    required this.api,
    required this.auth,
    required this.conversation,
    this.onChanged,
  });

  final LeagueService league;
  final ApiClient api;
  final AuthService auth;
  final Conversation conversation;
  final VoidCallback? onChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _message = TextEditingController();
  final _scrollController = ScrollController();
  final List<DirectMessage> _messages = [];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh(silent: false);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _message.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);

    try {
      final messages = await widget.league.messages(widget.conversation.id);
      await widget.league.markConversationRead(widget.conversation.id);
      final hadNewMessage =
          _messages.isEmpty ||
          messages.length != _messages.length ||
          (messages.isNotEmpty && messages.last.id != _messages.last.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      widget.onChanged?.call();
      if (hadNewMessage) _scrollToBottom();
    } on ApiException catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _refreshing = false;
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.league.sendMessage(widget.conversation.id, text);
      _message.clear();
      await _refresh(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayerId = widget.auth.currentPlayer!.id;
    final other = widget.conversation.otherParticipant(currentPlayerId);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (other != null)
              PlayerAvatar(player: other, api: widget.api, radius: 18),
            if (other != null) const SizedBox(width: 8),
            Expanded(child: Text(other?.fullName ?? 'Poruke')),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _refresh(silent: false),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final mine = message.sender.id == currentPlayerId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * .76,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? AppTheme.court : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: mine ? AppTheme.ink : AppTheme.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: AppTheme.mist,
                border: Border(
                  top: BorderSide(color: AppTheme.ink.withValues(alpha: .07)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Napiši poruku...',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(Icons.mark_chat_unread_outlined, size: 42),
          SizedBox(height: 10),
          Text(
            'Nema razgovora još.',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text('Klikni na Poruka i izaberi igrača.'),
        ],
      ),
    );
  }
}
