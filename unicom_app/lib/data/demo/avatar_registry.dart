/// Centralised placeholder-portrait registry.
///
/// Unsplash portrait photographs licensed under the Unsplash License
/// (free to use). These are DEVELOPMENT PLACEHOLDERS for the demo accounts
/// only — a real signed-in user's uploaded avatar always takes precedence
/// (see `UserProfile.avatarUrl`). Mapping is deterministic: the same contact
/// shows the same photo in the chats list, chat header, contacts list and
/// profile screen.
///
/// Kept in one place so the app can switch from bundled samples to
/// backend-provided images without touching widgets.
abstract final class AvatarAssets {
  /// Bundled portrait files (square, face-cropped, 400×400).
  static const List<String> all = [
    'assets/images/avatars/avatar_01.jpg',
    'assets/images/avatars/avatar_02.jpg',
    'assets/images/avatars/avatar_03.jpg',
    'assets/images/avatars/avatar_04.jpg',
    'assets/images/avatars/avatar_05.jpg',
    'assets/images/avatars/avatar_06.jpg',
    'assets/images/avatars/avatar_07.jpg',
    'assets/images/avatars/avatar_08.jpg',
    'assets/images/avatars/avatar_09.jpg',
    'assets/images/avatars/avatar_10.jpg',
    'assets/images/avatars/avatar_11.jpg',
    'assets/images/avatars/avatar_12.jpg',
    'assets/images/avatars/avatar_13.jpg',
    'assets/images/avatars/avatar_14.jpg',
    'assets/images/avatars/avatar_15.jpg',
    'assets/images/avatars/avatar_16.jpg',
  ];

  /// Explicit, stable assignment so each demo contact keeps one portrait.
  static const Map<String, String> _byUserId = {
    'usr_diego': 'assets/images/avatars/avatar_05.jpg',
    'usr_amara': 'assets/images/avatars/avatar_02.jpg',
    'usr_elodie': 'assets/images/avatars/avatar_09.jpg',
    'usr_kwame': 'assets/images/avatars/avatar_11.jpg',
    'usr_fatima': 'assets/images/avatars/avatar_14.jpg',
    'usr_lin': 'assets/images/avatars/avatar_06.jpg',
    'usr_sofia': 'assets/images/avatars/avatar_16.jpg',
    // The signed-in demo user.
    'me': 'assets/images/avatars/avatar_03.jpg',
    'usr_me': 'assets/images/avatars/avatar_03.jpg',
  };

  /// Deterministic portrait for a user id (falls back to a stable hash pick).
  static String? forUser(String? userId) {
    if (userId == null) return null;
    final fixed = _byUserId[userId];
    if (fixed != null) return fixed;
    if (all.isEmpty) return null;
    return all[userId.hashCode.abs() % all.length];
  }
}
