import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/shared/widgets/group_card.dart';
import 'package:easy_split/shared/widgets/expense_card.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';
import 'package:easy_split/shared/widgets/loading_overlay.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';
import 'package:easy_split/features/settlements/presentation/widgets/settle_up_sheet.dart';
import 'package:easy_split/core/utils/file_download.dart';

/// Groups Screen — shows all groups the user belongs to.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final currency = user?.currency ?? 'INR';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(groupsNotifierProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const EmptyState(
                    icon: Icons.group_outlined,
                    title: 'No groups yet',
                    subtitle: 'Create a group and start splitting expenses with your friends and family.',
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(groupsNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => GroupCard(
                group: groups[i],
                currency: currency,
                onTap: () => context.push(
                  AppRoutes.groupDetail.replaceAll(':groupId', groups[i].id),
                ),
              )
                  .animate(delay: Duration(milliseconds: i * 50))
                  .fadeIn(duration: 350.ms)
                  .slideX(begin: 0.05, duration: 350.ms),
            ),
          );
        },
        loading: () => const InlineLoader(),
        error: (e, _) => Center(
          child: Text(
            'Failed to load groups',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createGroup),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Group'),
      ),
    );
  }
}

/// Create Group bottom sheet
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final group = await ref.read(groupFormProvider.notifier).createGroup(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );
    if (group != null && mounted) {
      context.go(AppRoutes.groupDetail.replaceAll(':groupId', group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupFormProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Group'),
        actions: [
          TextButton(
            onPressed: state.isLoading ? null : _submit,
            child: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Group icon preview
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.group_rounded, size: 36, color: cs.onPrimary),
              ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms),
            ),
            const SizedBox(height: 28),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Trip to Goa, Flatmates',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a group name';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this group for?',
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),

            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Group Detail Screen
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return groupAsync.when(
      data: (group) => Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(group.name, overflow: TextOverflow.ellipsis)),
              if (group.isLocked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock_rounded, size: 18, color: Colors.amber),
              ],
            ],
          ),
          actions: [
            if (!group.isLocked)
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: () => _showAddMemberSheet(context, ref, groupId),
                tooltip: 'Add Member',
              ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'analytics') {
                  context.push('/groups/$groupId/analytics');
                } else if (value == 'export_excel') {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating Excel report...')),
                    );
                    final bytes = await ref.read(groupsRepositoryProvider).exportExpenses(groupId);
                    final cleanName = group.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                    final dateStr = DateTime.now().toIso8601String().split('T')[0];
                    final filename = 'EasySplit_${cleanName}_$dateStr.xlsx';
                    downloadFile(bytes, filename);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Report exported: $filename')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: ${e.toString().replaceAll('AppException(server): ', '')}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (value == 'export_pdf') {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating PDF report...')),
                    );
                    final bytes = await ref.read(groupsRepositoryProvider).exportPdf(groupId);
                    final cleanName = group.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                    final dateStr = DateTime.now().toIso8601String().split('T')[0];
                    final filename = 'EasySplit_${cleanName}_$dateStr.pdf';
                    downloadFile(bytes, filename);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF exported: $filename')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('PDF export failed: ${e.toString().replaceAll('AppException(server): ', '')}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (value == 'lock') {
                  await _showLockConfirmationDialog(context, ref, group, !group.isLocked);
                } else if (value == 'leave') {
                  if (group.isLocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot leave a locked group.')),
                    );
                    return;
                  }
                  final confirm = await _confirmDialog(
                    context,
                    'Leave Group',
                    'Are you sure you want to leave this group?',
                  );
                  if (confirm == true) {
                    await ref.read(groupsNotifierProvider.notifier).leaveGroup(groupId);
                    if (context.mounted) context.go(AppRoutes.groups);
                  }
                } else if (value == 'delete') {
                  await _showDeleteConfirmationDialog(context, ref, group);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'analytics',
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Statistics'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_excel',
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Export Expenses (.xlsx)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Export PDF (.pdf)'),
                    ],
                  ),
                ),
                if (group.createdBy == user?.id)
                  PopupMenuItem(
                    value: 'lock',
                    child: Row(
                      children: [
                        Icon(group.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(group.isLocked ? 'Unlock Group' : 'Lock Group'),
                      ],
                    ),
                  ),
                const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
                if (group.createdBy == user?.id)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Group', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (group.isLocked) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 20, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🔒 Locked — This group has been finalized.',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Members & Invitations
            Text('Members', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Active Members list
            Column(
              children: [
                ...group.members.map((m) {
                  final isOwner = m.userId == group.createdBy;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            avatarId: m.user?.avatarId,
                            name: m.user?.name ?? 'Member',
                            radius: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.user?.name ?? m.userId,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Builder(
                                  builder: (_) {
                                    final userEmail = m.user?.email;
                                    if (userEmail == null) return const SizedBox.shrink();
                                    return Text(
                                      userEmail,
                                      style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Owner',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // Group Invitations list (Owner Only)
                ref.watch(groupInvitationsProvider(groupId)).when(
                      data: (invitations) {
                        // Only the group owner is authorized to view pending/declined invitations in the group
                        if (group.createdBy != user?.id) return const SizedBox.shrink();

                        final nonAccepted = invitations.where((i) => i.status != 'accepted').toList();
                        if (nonAccepted.isEmpty) return const SizedBox.shrink();

                        final isCreatorOrSender = group.createdBy == user?.id;

                        return Column(
                          children: nonAccepted.map((inv) {
                            final isPending = inv.status == 'pending';
                            final isDeclined = inv.status == 'declined';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cs.outline.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: cs.outline.withValues(alpha: 0.2),
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        size: 18,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv.receiverName ?? inv.receiverEmail ?? 'Invited User',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (inv.receiverEmail != null && inv.receiverName != null)
                                            Text(
                                              inv.receiverEmail!,
                                              style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.surface,
                                        border: Border.all(color: cs.outline),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isPending ? 'Pending' : (isDeclined ? 'Declined' : inv.status),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isCreatorOrSender || inv.senderId == user?.id) ...[
                                      const SizedBox(width: 4),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                                        onSelected: (val) async {
                                          if (val == 'resend') {
                                            await ref
                                                .read(groupFormProvider.notifier)
                                                .resendInvitation(groupId: groupId, invitationId: inv.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Invitation resent!')),
                                              );
                                            }
                                          } else if (val == 'cancel') {
                                            await ref
                                                .read(groupFormProvider.notifier)
                                                .cancelInvitation(groupId: groupId, invitationId: inv.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Invitation cancelled')),
                                              );
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (isDeclined)
                                            const PopupMenuItem(
                                              value: 'resend',
                                              child: Text('Resend Invitation'),
                                            ),
                                          if (isPending)
                                            const PopupMenuItem(
                                              value: 'cancel',
                                              child: Text('Cancel Invitation', style: TextStyle(color: Colors.red)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
              ],
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            // Settlement Summary Section
            _SettlementSummaryCard(
              groupId: groupId,
              currency: user?.currency ?? 'INR',
            ),

            const SizedBox(height: 8),

            // Expenses section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expenses', style: theme.textTheme.titleMedium),
                if (!group.isLocked)
                  TextButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.addExpense
                          .replaceAll(':groupId', groupId),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ref.watch(groupExpensesProvider(groupId)).when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No expenses added yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.secondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: expenses.map((exp) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ExpenseCard(
                          expense: exp,
                          currentUserId: user?.id ?? '',
                          currency: user?.currency ?? 'INR',
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Failed to load expenses: $e', style: TextStyle(color: cs.error)),
                ),
          ],
        ),
      ),
      loading: () => const Scaffold(body: InlineLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('EasySplit'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.groups),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.group_off_outlined,
              title: 'Group No Longer Available',
              subtitle: 'This group has been deleted by the owner. A complete financial backup report has been emailed to your registered address for your records.',
              actionLabel: 'Back to Groups',
              onAction: () => context.go(AppRoutes.groups),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context, WidgetRef ref, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddMemberSheet(groupId: groupId, parentContext: context),
    );
  }

  Future<bool?> _confirmDialog(
    BuildContext context,
    String title,
    String message, {
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(isDestructive ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  final String groupId;
  final BuildContext parentContext;

  const _AddMemberSheet({required this.groupId, required this.parentContext});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupFormProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Member', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Member Email',
              hintText: 'friend@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(widget.parentContext);
                      final navigator = Navigator.of(context);
                      final ok = await ref.read(groupFormProvider.notifier).addMember(
                            groupId: widget.groupId,
                            email: _emailController.text,
                          );
                      if (!mounted) return;
                      if (ok) {
                        navigator.pop();
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Invitation sent!')),
                        );
                      }
                    },
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Member'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettlementSummaryCard extends ConsumerWidget {
  final String groupId;
  final String currency;

  const _SettlementSummaryCard({required this.groupId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = ref.watch(currentUserProvider);
    final currentUserId = (user?.id ?? '').toLowerCase().trim();
    final symbol = currency == 'INR' ? '₹' : currency;

    final debts = ref.watch(groupSimplifiedDebtsProvider(groupId));
    final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Settlement Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push(AppRoutes.settlementHistory),
              child: const Text('History'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (_) {
            final myDebts = debts.where((d) {
              final from = d.fromUserId.toLowerCase().trim();
              final to = d.toUserId.toLowerCase().trim();
              return from == currentUserId || to == currentUserId;
            }).toList();

            final pendingSettlements = settlementsAsync.valueOrNull?.where((s) {
              final from = s.fromUser.toLowerCase().trim();
              final to = s.toUser.toLowerCase().trim();
              return s.status.toLowerCase() == 'pending' && (from == currentUserId || to == currentUserId);
            }).toList() ?? [];

            if (myDebts.isEmpty && pendingSettlements.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      'Everything is settled',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                ...myDebts.map((d) {
                  final isOwedByMe = d.fromUserId.toLowerCase().trim() == currentUserId;
                  final otherName = isOwedByMe ? d.toUserName : d.fromUserName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOwedByMe ? 'You owe $otherName' : '$otherName owes You',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$symbol ${d.amount.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOwedByMe ? cs.error : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwedByMe)
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => SettleUpSheet(
                                  groupId: groupId,
                                  receiverId: d.toUserId,
                                  receiverName: d.toUserName,
                                  outstandingAmount: d.amount,
                                  currency: currency,
                                ),
                              );
                            },
                            icon: const Icon(Icons.payment_rounded, size: 16),
                            label: const Text('Settle Up'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        else
                          Text(
                            'Waiting for payment',
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  );
                }),

                ...pendingSettlements.map((s) {
                  final isPayer = s.fromUser == currentUserId;
                  final otherName = isPayer ? (s.toUserName ?? 'Receiver') : (s.fromUserName ?? 'Payer');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPayer ? 'Payment to $otherName pending confirmation' : '$otherName marked $symbol${s.amount.toStringAsFixed(2)} paid',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text('${s.paymentMethod} • $symbol${s.amount.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (!isPayer)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                                onPressed: () => ref.read(settlementsNotifierProvider.notifier).rejectPayment(s.id, groupId: groupId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                onPressed: () => ref.read(settlementsNotifierProvider.notifier).confirmPayment(s.id, groupId: groupId),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

Future<void> _showDeleteConfirmationDialog(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Group'),
      content: const Text(
        'Deleting this group is permanent.\n\n'
        'Before deletion, an Excel report containing the complete expense history will be generated and emailed to every group member.\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Export & Delete'),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating backup reports & deleting group...')),
      );
      await ref.read(groupsNotifierProvider.notifier).deleteGroup(group.id);
      if (context.mounted) {
        context.go(AppRoutes.groups);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted and backup reports emailed successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group: ${e.toString().replaceAll('AppException(server): ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

Future<void> _showLockConfirmationDialog(
  BuildContext context,
  WidgetRef ref,
  Group group,
  bool isLocking,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isLocking ? 'Lock Group' : 'Unlock Group'),
      content: Text(
        isLocking
            ? 'Locking this group will prevent any future modifications (expenses, members, settlements) until it is unlocked.'
            : 'Unlocking this group will re-enable adding and editing expenses.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isLocking ? Colors.black87 : Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(isLocking ? 'Lock Group' : 'Unlock Group'),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    try {
      await ref.read(groupsNotifierProvider.notifier).toggleGroupLock(group.id, isLocking);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isLocking ? 'Group locked successfully' : 'Group unlocked successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update lock: ${e.toString().replaceAll('AppException(server): ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


