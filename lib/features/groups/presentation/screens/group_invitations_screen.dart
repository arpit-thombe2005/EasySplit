import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:easy_split/features/groups/domain/models/invitation.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';
import 'package:easy_split/shared/widgets/loading_overlay.dart';

/// Group Invitations Screen — shows pending group invitations.
class GroupInvitationsScreen extends ConsumerWidget {
  const GroupInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingInvitationsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Invitations'),
      ),
      body: pendingAsync.when(
        data: (invitations) {
          if (invitations.isEmpty) {
            return const EmptyState(
              icon: Icons.mail_outline_rounded,
              title: 'No pending invitations',
              subtitle: 'When friends invite you to join their groups, the invitations will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(pendingInvitationsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: invitations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final inv = invitations[i];
                return _InvitationCard(invitation: inv)
                    .animate(delay: Duration(milliseconds: i * 50))
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.05, duration: 350.ms);
              },
            ),
          );
        },
        loading: () => const InlineLoader(),
        error: (e, _) => Center(
          child: Text(
            'Failed to load invitations',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  final GroupInvitation invitation;

  const _InvitationCard({required this.invitation});

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _isProcessing = false;

  Future<void> _accept() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(pendingInvitationsProvider.notifier).acceptInvitation(widget.invitation.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Joined "${widget.invitation.groupName ?? 'group'}"!')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll(RegExp(r'^AppException\([^)]+\):\s*'), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(pendingInvitationsProvider.notifier).declineInvitation(widget.invitation.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll(RegExp(r'^AppException\([^)]+\):\s*'), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inv = widget.invitation;

    final dateStr = inv.createdAt != null
        ? DateFormat('MMM d, yyyy').format(inv.createdAt!)
        : 'Recently';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.group_rounded, size: 24, color: cs.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.groupName ?? 'Unnamed Group',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invited by ${inv.senderName ?? 'Someone'} • $dateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
