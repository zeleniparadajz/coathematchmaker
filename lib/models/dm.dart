import 'player.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageBy,
  });

  final String id;
  final List<Player> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Player? lastMessageBy;
  final int unreadCount;

  Player? otherParticipant(String currentPlayerId) {
    return participants
        .where((player) => player.id != currentPlayerId)
        .firstOrNull;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['_id'] ?? json['id']).toString(),
      participants: (json['participants'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Player.fromJson)
          .toList(),
      lastMessage: json['lastMessage'],
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] ?? ''),
      lastMessageBy: json['lastMessageBy'] is Map<String, dynamic>
          ? Player.fromJson(json['lastMessageBy'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final Player sender;
  final String text;
  final DateTime createdAt;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: (json['_id'] ?? json['id']).toString(),
      sender: Player.fromJson(json['sender'] ?? <String, dynamic>{}),
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
