import 'package:flutter/material.dart';

import 'message.dart';
import 'user.dart';

/// A 1:1 conversation record. Group conversations are part of the schema
/// roadmap; the MVP demo implements 1:1 threads.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.members,
    required this.createdAt,
    this.typingUserIds = const {},
    this.draft = '',
    this.isGroup = false,
    this.title,
  });

  final String id;

  /// [0] = other user, [1] = me (server orders by join time; demo keeps 1:1).
  /// For groups this lists every member (no fixed ordering contract).
  final List<UserProfile> members;
  final DateTime createdAt;

  /// members currently typing (demo simulation).
  final Set<String> typingUserIds;
  final String draft;

  /// Group conversations list every member and use [title] for display.
  final bool isGroup;
  final String? title;
  UserProfile get other => members.first;

  /// Every member except the signed-in user. The backend always orders
  /// members others-first with me last (1:1: [other, me]; groups append me).
  List<UserProfile> get others =>
      members.length <= 1 ? const [] : members.sublist(0, members.length - 1);

  bool get isTyping => typingUserIds.isNotEmpty;

  /// Conversation display title: peer name, or group title.
  String? get displayTitle => isGroup ? title : other.name;

  Conversation copyWith({
    List<UserProfile>? members,
    Set<String>? typingUserIds,
    String? draft,
    bool? isGroup,
    String? title,
  }) {
    return Conversation(
      id: id,
      members: members ?? this.members,
      createdAt: createdAt,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      draft: draft ?? this.draft,
      isGroup: isGroup ?? this.isGroup,
      title: title ?? this.title,
    );
  }
}

/// List tile view-model computed from messages + prefs.
@immutable
class ConversationTile {
  const ConversationTile({
    required this.conversation,
    required this.unread,
    required this.lastMessage,
    required this.previewText,
    required this.previewOrigin,
  });

  final Conversation conversation;
  final int unread;
  final Message? lastMessage;

  /// Best-available preview (translated text when it exists).
  final String previewText;

  /// Which language the preview text is in.
  final String? previewOrigin;
}
