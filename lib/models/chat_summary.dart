import 'package:flutter/material.dart';

enum ChatActivity { offline, online }

enum ChatType { direct, group, channel }

class ChatTypingUpdate {
  final String chatId;
  final bool isTyping;

  const ChatTypingUpdate({required this.chatId, required this.isTyping});
}

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
  final bool isMarkedUnread;
  final bool isArchived;

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
    this.isMarkedUnread = false,
    this.isArchived = false,
  });

  bool get isPinned => pinnedAt != null;
  bool get hasNewIncoming => unreadCount > 0;
  bool get isNew => hasNewIncoming && !isMarkedUnread;
  bool get isUnread => hasNewIncoming || isMarkedUnread;
  bool get isActive => activity == ChatActivity.online;

  bool get shouldShowHoldBadge => isMarkedUnread;

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
    bool clearPinnedAt = false,
    DateTime? lastIncomingAt,
    DateTime? lastOutgoingAt,
    int? unreadCount,
    bool? isMarkedUnread,
    bool? isArchived,
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
      pinnedAt: clearPinnedAt ? null : pinnedAt ?? this.pinnedAt,
      lastIncomingAt: lastIncomingAt ?? this.lastIncomingAt,
      lastOutgoingAt: lastOutgoingAt ?? this.lastOutgoingAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isMarkedUnread: isMarkedUnread ?? this.isMarkedUnread,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
