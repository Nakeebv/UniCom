import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/utils.dart';
import '../../data/models/user.dart';
import '../../providers.dart';
import '../../shared/widgets/kit_scaffold.dart';
import '../../shared/widgets/ui_kit.dart';

enum CallType { incoming, outgoing, missed }

enum CallChannel { voice, video }

@immutable
class CallLogEntry {
  const CallLogEntry({
    required this.contactId,
    required this.startedMinutesAgo,
    required this.type,
    required this.channel,
    this.duration,
  });
  final String contactId;
  final int startedMinutesAgo;
  final CallType type;
  final CallChannel channel;
  final Duration? duration;
}

const _demoLog = <CallLogEntry>[
  CallLogEntry(
    contactId: 'usr_diego',
    startedMinutesAgo: 12,
    type: CallType.incoming,
    channel: CallChannel.voice,
    duration: Duration(minutes: 4, seconds: 36),
  ),
  CallLogEntry(
    contactId: 'usr_amara',
    startedMinutesAgo: 95,
    type: CallType.missed,
    channel: CallChannel.voice,
  ),
  CallLogEntry(
    contactId: 'usr_kwame',
    startedMinutesAgo: 220,
    type: CallType.outgoing,
    channel: CallChannel.video,
    duration: Duration(minutes: 11, seconds: 12),
  ),
  CallLogEntry(
    contactId: 'usr_fatima',
    startedMinutesAgo: 1500,
    type: CallType.incoming,
    channel: CallChannel.video,
    duration: Duration(minutes: 6, seconds: 2),
  ),
  CallLogEntry(
    contactId: 'usr_amara',
    startedMinutesAgo: 2600,
    type: CallType.outgoing,
    channel: CallChannel.voice,
    duration: Duration(minutes: 2, seconds: 40),
  ),
  CallLogEntry(
    contactId: 'usr_elodie',
    startedMinutesAgo: 4300,
    type: CallType.missed,
    channel: CallChannel.video,
  ),
];

/// Calls tab — Chatbox kit: dark header with video-call FAB, white sheet
/// with "Recent" list (incoming/outgoing/missed + voice/video glyph).
class CallsSoonScreen extends StatelessWidget {
  const CallsSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KitPage(
      title: 'Calls',
      leading: const Icon(Icons.videocam_rounded),
      onLeading: () => context.push('/call/live/usr_diego'),
      trailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => context.push('/call/incoming/usr_amara'),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      sheetChildren: [
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final backend = ref.watch(backendProvider);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                      color: Palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final e in _demoLog.reversed)
                    _CallTile(
                      entry: e,
                      contact: backend.contactById(e.contactId),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.entry, required this.contact});

  final CallLogEntry entry;
  final UserProfile? contact;

  @override
  Widget build(BuildContext context) {
    final name = contact?.name ?? 'Unknown';
    final missed = entry.type == CallType.missed;
    final directionIcon =
        entry.type == CallType.outgoing
            ? Icons.call_made_rounded
            : entry.type == CallType.incoming
            ? Icons.call_received_rounded
            : Icons.call_missed_outgoing_rounded;
    final directionColor = missed ? Palette.danger : Palette.success;

    return InkWell(
      onTap:
          () => context.push(
            entry.channel == CallChannel.voice
                ? '/call/incoming/${entry.contactId}'
                : '/call/live/${entry.contactId}',
          ),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            contact != null
                ? UserAvatar(
                  name: contact!.name,
                  gradient: contact!.gradient,
                  userId: contact!.id,
                  imageUrl: contact!.avatarUrl,
                  size: 54,
                )
                : Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCDCE0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color:
                                missed ? Palette.danger : Palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(directionIcon, size: 15, color: directionColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          entry.duration == null
                              ? 'Missed call'
                              : formatShortDuration(entry.duration!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${formatListStamp(DateTime.now().subtract(Duration(minutes: entry.startedMinutesAgo)), DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed:
                  () => context.push('/call/incoming/${entry.contactId}'),
              icon: Icon(
                entry.channel == CallChannel.video
                    ? Icons.videocam_rounded
                    : Icons.phone_outlined,
                size: 22,
                color: Palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatShortDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
