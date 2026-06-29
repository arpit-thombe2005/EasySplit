import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';

/// Bottom sheet for recording a settlement payment (Settle Up flow).
class SettleUpSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String receiverId;
  final String receiverName;
  final double outstandingAmount;
  final String currency;

  const SettleUpSheet({
    super.key,
    required this.groupId,
    required this.receiverId,
    required this.receiverName,
    required this.outstandingAmount,
    this.currency = 'INR',
  });

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String _selectedMethod = 'UPI';
  bool _isSubmitting = false;
  String? _error;

  final List<String> _methods = ['UPI', 'Cash', 'Bank Transfer', 'Other'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.outstandingAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid payment amount');
      return;
    }

    if (amount > widget.outstandingAmount + 0.01) {
      setState(() => _error = 'Amount cannot exceed total debt of ${widget.currency} ${widget.outstandingAmount.toStringAsFixed(2)}');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final res = await ref.read(settlementsNotifierProvider.notifier).recordPayment(
          toUserId: widget.receiverId,
          groupId: widget.groupId,
          amount: amount,
          paymentMethod: _selectedMethod,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ${widget.currency} ${amount.toStringAsFixed(2)} recorded! Waiting for receiver confirmation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = 'Failed to record payment. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = widget.currency == 'INR' ? '₹' : widget.currency;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settle Up',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Receiver Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    child: Text(
                      widget.receiverName[0].toUpperCase(),
                      style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paying to ${widget.receiverName}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Total Debt: $symbol ${widget.outstandingAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
              const SizedBox(height: 10),
            ],

            // Payment Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount ($symbol)',
                prefixText: '$symbol ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: 'Supports partial payments',
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method Selector
            Text('Payment Method', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _methods.map((m) {
                final isSelected = _selectedMethod == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedMethod = m),
                  selectedColor: cs.primary,
                  backgroundColor: cs.surfaceContainerHigh,
                  side: BorderSide(
                    color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Optional Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Optional Note (e.g. GPay ref #)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
