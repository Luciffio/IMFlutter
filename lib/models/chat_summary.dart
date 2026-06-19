import 'package:flutter/material.dart';

/// A single participant in a chat — used to render the avatar badge(s) on
/// the chat list row and in the chat header.
///
/// For the mock repository we point [portraitAsset] at a bundled asset.
/// For a real Telegram backend this will hold a file path to a cached
/// profile photo (or null when the user has no photo, in which case the
/// banner falls back to a plain colored square).
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

/// A row in the chat list. [avatarLabel] is a compact one- or two-letter
/// identity derived from the Telegram chat title.
class ChatSummary {
  /// Stable id — maps to a Telegram chatId once the real backend is wired up.
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatParticipant> participants;
  final String? avatarPath;
  final String? avatarLabel;
  final bool showActivityBadge;
  final bool isPinned;

  const ChatSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.participants,
    this.avatarPath,
    this.avatarLabel,
    this.showActivityBadge = false,
    this.isPinned = false,
  });
}
