import 'package:flutter/material.dart';

enum ChatActivity { offline, online }

enum ChatType { direct, group, channel }

/// A single participant in a chat. Mock data points [portraitAsset] at bundled
/// assets; a real backend can replace it with a cached profile photo path.
class ChatParticipant {
  final String name;
  final String? portraitAsset;
  final Color color;

  const ChatParticipant({
    required this.name,
    this.portraitAsset,
    required this.color,
  });
}

/// Backend-facing chat row model.
///
/// The UI should read derived states from this class instead of hand-placing
/// HOLD/NEW/pinned/online badges in widgets.
class ChatSummary {
  /// Stable id. This maps to Telegram's chat id once the real backend is wired.
  final String id;
  final String title;
  final ChatType type;
  final DateTime updatedAt;
  final List<ChatParticipant> participants;
  final String? lastMessagePreview;
  final String? avatarPath;
  final String? avatarLabel;
  final ChatActivity activity;
  final DateTime? pinnedAt;
  final DateTime? lastIncomingAt;
  final DateTime? lastOutgoingAt;
  final int unreadCount;

  const ChatSummary({
    required this.id,
    required this.title,
    required this.type,
    required this.updatedAt,
    required this.participants,
    this.lastMessagePreview,
    this.avatarPath,
    this.avatarLabel,
    this.activity = ChatActivity.offline,
    this.pinnedAt,
    this.lastIncomingAt,
    this.lastOutgoingAt,
    this.unreadCount = 0,
  });

  bool get isPinned => pinnedAt != null;
  bool get hasNewIncoming => unreadCount > 0;
  bool get isNew => hasNewIncoming;
  bool get isUnread => hasNewIncoming;
  bool get isActive => activity == ChatActivity.online;

  /// Persona's HOLD is the "we saw it, but still owe them an answer" state.
  /// NEW takes visual priority while the incoming message is still unread.
  bool get needsReply {
    final incoming = lastIncomingAt;
    if (incoming == null) return false;
    final outgoing = lastOutgoingAt;
    return outgoing == null || incoming.isAfter(outgoing);
  }

  bool get shouldShowHoldBadge => needsReply && !hasNewIncoming;

  ChatSummary copyWith({
    String? id,
    String? title,
    ChatType? type,
    DateTime? updatedAt,
    List<ChatParticipant>? participants,
    String? lastMessagePreview,
    String? avatarPath,
    String? avatarLabel,
    ChatActivity? activity,
    DateTime? pinnedAt,
    DateTime? lastIncomingAt,
    DateTime? lastOutgoingAt,
    int? unreadCount,
  }) {
    return ChatSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarLabel: avatarLabel ?? this.avatarLabel,
      activity: activity ?? this.activity,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      lastIncomingAt: lastIncomingAt ?? this.lastIncomingAt,
      lastOutgoingAt: lastOutgoingAt ?? this.lastOutgoingAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
