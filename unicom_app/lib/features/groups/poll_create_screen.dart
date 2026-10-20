import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../providers.dart';

/// "Create a poll" — question, options with "Add option", teal Create pill.
/// Post-launch the poll renders as a MessageBubble (kind: poll).
class PollCreateScreen extends ConsumerStatefulWidget {
  const PollCreateScreen({super.key});

  @override
  ConsumerState<PollCreateScreen> createState() => _PollCreateScreenState();
}

class _PollCreateScreenState extends ConsumerState<PollCreateScreen> {
  final _question = TextEditingController();
  final _controllers = [
    TextEditingController(text: 'Yes'),
    TextEditingController(text: 'No'),
  ];

  @override
  void dispose() {
    _question.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _create() {
    final question = _question.text.trim();
    final options =
        _controllers.map((c) => c.text.trim()).lessThanEmpty.toList();
    if (question.isEmpty || options.length < 2) return;
    final id = GoRouterState.of(context).pathParameters['id']!;
    ref.read(backendProvider).createPoll(id, question, options);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final filled =
        _question.text.trim().isNotEmpty &&
        _controllers.every((c) => c.text.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Create a poll',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Palette.danger.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.poll_rounded,
                  color: Palette.danger,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Ask your question…',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            for (var i = 0; i < _controllers.length; i++)
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Palette.iris.withValues(alpha: .1),
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Palette.irisDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Option ${''}',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_controllers.length > 2)
                    IconButton(
                      onPressed: () => setState(() => _controllers.removeAt(i)),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            TextButton.icon(
              onPressed:
                  _controllers.length >= 4
                      ? null
                      : () => setState(
                        () => _controllers.add(TextEditingController()),
                      ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add option',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: filled ? Palette.cyan : Palette.darkCard2,
                  foregroundColor:
                      filled ? const Color(0xFF00232B) : Palette.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: filled ? _create : null,
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Iterable<String> {
  List<String> get lessThanEmpty => where((s) => s.isNotEmpty).toList();
}
