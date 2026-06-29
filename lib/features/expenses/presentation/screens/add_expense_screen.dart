import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';

/// Add Expense Screen
class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedParticipants = {};
  String? _selectedPaidBy;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one participant')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final paidById = _selectedPaidBy ?? user.id;

    final expense = await ref.read(addExpenseNotifierProvider.notifier).submitExpense(
          groupId: widget.groupId,
          paidBy: paidById,
          title: _titleController.text.trim(),
          amount: double.tryParse(_amountController.text) ?? 0,
          participantIds: _selectedParticipants.toList(),
          expenseDate: _selectedDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (expense != null && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${expense.title}" expense added!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addExpenseNotifierProvider);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(addExpenseNotifierProvider.notifier).reset();
            context.pop();
          },
        ),
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: state.isLoading ? null : _submit,
            child: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'What was it for?',
                hintText: 'e.g. Dinner at Barbeque Nation',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a title';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: user?.currency == 'INR' ? '₹ ' : '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final amt = double.tryParse(v);
                if (amt == null || amt <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category & Split Type row
            Row(
              children: [
                Expanded(child: _CategoryPicker(state: state, ref: ref)),
                const SizedBox(width: 12),
                Expanded(child: _SplitTypePicker(state: state, ref: ref)),
              ],
            ),
            const SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 20, color: cs.secondary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, yyyy').format(_selectedDate),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional details...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Paid By Dropdown
            Text('Paid by', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            groupAsync.when(
              data: (group) {
                if (_selectedPaidBy == null && group.members.isNotEmpty) {
                  final currentInGroup = group.members.any((m) => m.userId == user?.id);
                  _selectedPaidBy = currentInGroup ? user?.id : group.members.first.userId;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPaidBy,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: group.members.map((m) {
                        final name = m.user?.name ?? m.userId;
                        final isMe = m.userId == user?.id;
                        return DropdownMenuItem<String>(
                          value: m.userId,
                          child: Row(
                            children: [
                              AppAvatar(
                                name: name,
                                avatarId: m.user?.avatarId,
                                radius: 14,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isMe ? '$name (You)' : name,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPaidBy = val);
                        }
                      },
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Participants
            Text('Split with', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),

            groupAsync.when(
              data: (group) {
                // Auto-select all members on first load
                if (_selectedParticipants.isEmpty) {
                  for (final m in group.members) {
                    _selectedParticipants.add(m.userId);
                  }
                }
                return Column(
                  children: group.members.map((member) {
                    final isSelected = _selectedParticipants.contains(member.userId);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedParticipants.add(member.userId);
                          } else {
                            _selectedParticipants.remove(member.userId);
                          }
                        });
                      },
                      title: Text(member.user?.name ?? member.userId),
                      secondary: AppAvatar(
                        name: member.user?.name ?? member.userId,
                        avatarId: member.user?.avatarId,
                        radius: 18,
                      ),
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => const Text('Error loading members'),
            ),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final AddExpenseState state;
  final WidgetRef ref;

  const _CategoryPicker({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Category', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ...AppConstants.expenseCategories.map((cat) => ListTile(
                    title: Text(cat),
                    trailing: cat == state.category
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, cat),
                  )),
            ],
          ),
        );
        if (selected != null) {
          ref.read(addExpenseNotifierProvider.notifier).setCategory(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.category_outlined, size: 18, color: cs.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.category,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitTypePicker extends StatelessWidget {
  final AddExpenseState state;
  final WidgetRef ref;

  const _SplitTypePicker({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<SplitType>(
          context: context,
          builder: (ctx) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Split Type', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ...SplitType.values.map((t) => ListTile(
                    title: Text(t.name.toUpperCase()),
                    subtitle: Text(_splitDescription(t)),
                    trailing: t == state.splitType
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, t),
                  )),
            ],
          ),
        );
        if (selected != null) {
          ref.read(addExpenseNotifierProvider.notifier).setSplitType(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.call_split_rounded, size: 18, color: cs.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.splitType.name,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _splitDescription(SplitType t) {
    switch (t) {
      case SplitType.equal: return 'Split equally';
      case SplitType.exact: return 'Enter exact amounts';
      case SplitType.percentage: return 'By percentage';
      case SplitType.shares: return 'By shares / ratio';
    }
  }
}
