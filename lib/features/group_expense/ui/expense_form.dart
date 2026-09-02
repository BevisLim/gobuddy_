import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/ui/widgets/primary_button.dart';
import '../model/expense_category.dart';
import '../model/expense_constants.dart';
import '../model/expense_date_utils.dart';
import '../model/expense_form_validation.dart';
import '../model/expense_split.dart';
import 'state/expense_form_state.dart';
import 'view_model/expense_view_model.dart';
import 'widgets/app_text_field.dart';
import 'widgets/budget_feedback_panel.dart';
import 'widgets/category_chip.dart';
import 'widgets/currency_chip.dart';
import 'widgets/load_error_state.dart';

class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({
    super.key,
    required this.tripId,
    this.expenseId,
    required this.onSaved,
  });

  final String tripId;
  final String? expenseId;
  final ValueChanged<String> onSaved;

  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _selectedParticipants = <String>{};
  final _customShares = <String, String>{};
  final _percentages = <String, String>{};
  int? _categoryId;
  String? _payerId;
  String _currency = 'MYR';
  DateTime _expenseDate = DateTime.now();
  ExpenseSplitMethod _splitMethod = ExpenseSplitMethod.equal;
  String? _selectedReceiptPath;
  bool _removeReceipt = false;
  bool _initialized = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = expenseViewModelProvider(
      tripId: widget.tripId,
      expenseId: widget.expenseId,
    );
    final formState = ref.watch(provider);
    return formState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => LoadErrorState(
        message: 'Unable to load expense information.',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (state) {
        _initialize(state);
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (state.errorMessage != null) ...[
                BudgetFeedbackPanel(
                  message: state.errorMessage!,
                  isError: true,
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                label: 'Expense Title *',
                controller: _title,
                validator: (value) => ExpenseFormValidation.title(value ?? ''),
              ),
              const SizedBox(height: 20),
              _label(context, 'Category *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.categories
                    .map((category) => CategoryChip(
                          label: category.name,
                          icon: _categoryIcon(category),
                          selected: _categoryId == category.categoryId,
                          onSelected: (_) => setState(
                            () => _categoryId = category.categoryId,
                          ),
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Amount *',
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => ExpenseFormValidation.amount(value ?? ''),
              ),
              const SizedBox(height: 16),
              _label(context, 'Currency'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseConstants.supportedCurrencies
                    .map((currency) => CurrencyChip(
                          currency: currency,
                          selected: _currency == currency,
                          onSelected: (_) =>
                              setState(() => _currency = currency),
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _payerId,
                decoration: const InputDecoration(labelText: 'Paid By *'),
                items: state.travellers
                    .map((traveller) => DropdownMenuItem(
                          value: traveller.userId,
                          child: Text(traveller.displayName),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() => _payerId = value),
                validator: (value) => ExpenseFormValidation.requiredSelection(
                  value,
                  'Payer',
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expense Date'),
                subtitle: Text(ExpenseDateUtils.formatDate(_expenseDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              _label(context, 'Split Method'),
              const SizedBox(height: 8),
              SegmentedButton<ExpenseSplitMethod>(
                segments: const [
                  ButtonSegment(
                    value: ExpenseSplitMethod.equal,
                    label: Text('Equal'),
                  ),
                  ButtonSegment(
                    value: ExpenseSplitMethod.custom,
                    label: Text('Custom'),
                  ),
                  ButtonSegment(
                    value: ExpenseSplitMethod.percentage,
                    label: Text('%'),
                  ),
                ],
                selected: {_splitMethod},
                onSelectionChanged: (selection) =>
                    setState(() => _splitMethod = selection.first),
              ),
              const SizedBox(height: 14),
              _label(context, 'Participants *'),
              ...state.travellers.map((traveller) {
                final selected =
                    _selectedParticipants.contains(traveller.userId);
                return Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        title: Text(traveller.displayName),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            _selectedParticipants.add(traveller.userId);
                          } else {
                            _selectedParticipants.remove(traveller.userId);
                          }
                        }),
                      ),
                    ),
                    if (selected && _splitMethod != ExpenseSplitMethod.equal)
                      SizedBox(
                        width: 105,
                        child: TextFormField(
                          key: ValueKey(
                            '${_splitMethod.name}-${traveller.userId}',
                          ),
                          initialValue:
                              _splitMethod == ExpenseSplitMethod.custom
                                  ? _customShares[traveller.userId]
                                  : _percentages[traveller.userId],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _splitMethod == ExpenseSplitMethod.custom
                                ? state.baseCurrency
                                : '%',
                          ),
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed < 0) {
                              return _splitMethod == ExpenseSplitMethod.custom
                                  ? 'Invalid amount'
                                  : 'Invalid %';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final target =
                                _splitMethod == ExpenseSplitMethod.custom
                                    ? _customShares
                                    : _percentages;
                            target[traveller.userId] = value;
                          },
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Notes',
                controller: _notes,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              _receiptSection(state),
              const SizedBox(height: 26),
              PrimaryButton(
                text: state.isSaving
                    ? 'Saving...'
                    : widget.expenseId == null
                        ? 'Add Expense'
                        : 'Update Expense',
                backgroundColor: const Color(0xFF7C3AED),
                isEnable: !state.isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _receiptSection(ExpenseFormState state) {
    final path = _selectedReceiptPath ??
        (_removeReceipt ? null : state.receipt?.imagePath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Receipt'),
        const SizedBox(height: 8),
        if (path != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 100,
                child: Center(child: Text('Receipt preview unavailable')),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _selectedReceiptPath = null;
              _removeReceipt = true;
            }),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove receipt'),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: _chooseReceiptSource,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add receipt'),
          ),
      ],
    );
  }

  void _initialize(ExpenseFormState state) {
    if (_initialized) return;
    _initialized = true;
    final expense = state.expense;
    if (expense == null) {
      _payerId =
          state.travellers.isEmpty ? null : state.travellers.first.userId;
      _selectedParticipants.addAll(state.travellers.map((item) => item.userId));
      return;
    }
    _title.text = expense.title;
    _amount.text = expense.originalAmount.toStringAsFixed(2);
    _notes.text = expense.notes ?? '';
    _categoryId = expense.categoryId;
    _payerId = expense.paidByUserId;
    _currency = expense.currencyCode;
    _expenseDate = expense.expenseDate;
    _selectedParticipants.addAll(state.participants.map((item) => item.userId));
    final equal = state.participants.isNotEmpty &&
        state.participants
                    .map((item) => item.shareAmount)
                    .reduce((a, b) => a > b ? a : b) -
                state.participants
                    .map((item) => item.shareAmount)
                    .reduce((a, b) => a < b ? a : b) <=
            0.01;
    _splitMethod = equal
        ? ExpenseSplitMethod.equal
        : state.participants.every((item) => item.sharePercentage != null)
            ? ExpenseSplitMethod.percentage
            : ExpenseSplitMethod.custom;
    for (final participant in state.participants) {
      _customShares[participant.userId] =
          participant.shareAmount.toStringAsFixed(2);
      _percentages[participant.userId] =
          participant.sharePercentage?.toStringAsFixed(2) ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = expenseViewModelProvider(
      tripId: widget.tripId,
      expenseId: widget.expenseId,
    );
    double parse(String? value) => double.tryParse(value ?? '') ?? 0;
    final saved = await ref.read(provider.notifier).save(
          title: _title.text,
          categoryId: _categoryId,
          amount: _amount.text,
          currency: _currency,
          payerId: _payerId,
          expenseDate: _expenseDate,
          participantIds: _selectedParticipants.toList(growable: false),
          splitMethod: _splitMethod,
          customShares: _customShares.map(
            (key, value) => MapEntry(key, parse(value)),
          ),
          percentages: _percentages.map(
            (key, value) => MapEntry(key, parse(value)),
          ),
          notes: _notes.text,
          selectedReceiptPath: _selectedReceiptPath,
          removeReceipt: _removeReceipt,
        );
    if (!mounted || !saved) return;
    final id = ref.read(provider).value?.savedExpenseId;
    if (id != null) widget.onSaved(id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final image =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (image != null && mounted) {
      setState(() {
        _selectedReceiptPath = image.path;
        _removeReceipt = false;
      });
    }
  }

  Text _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF281958),
              fontWeight: FontWeight.w800,
            ),
      );

  IconData _categoryIcon(ExpenseCategory category) =>
      switch (category.iconName) {
        'hotel' => Icons.hotel_outlined,
        'flight' => Icons.flight_outlined,
        'food' || 'restaurant' => Icons.restaurant_outlined,
        'transportation' => Icons.directions_car_outlined,
        'fuel' => Icons.local_gas_station_outlined,
        'parking' => Icons.local_parking_outlined,
        'shopping' => Icons.shopping_bag_outlined,
        'entertainment' => Icons.movie_outlined,
        'attraction' => Icons.attractions_outlined,
        _ => Icons.more_horiz,
      };
}
