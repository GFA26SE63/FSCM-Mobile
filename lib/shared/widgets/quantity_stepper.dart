import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// − [value] + control; [step] cartons per tap, clamped to 0..[max].
class QuantityStepper extends StatefulWidget {
  static const double editableWidth = 120;
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.editable = false,
    this.enabled = true,
    this.onValidationChanged,
    this.unit = 'thùng',
  });

  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool editable;
  final bool enabled;
  final ValueChanged<bool>? onValidationChanged;
  final String unit;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    // Returning to a filtered-out row restores its last committed quantity.
    // Clear any parent validation flag left by the previous, disposed editor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.editable) {
        widget.onValidationChanged?.call(widget.value >= widget.min &&
            widget.value <= widget.max &&
            widget.value % widget.step == 0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _input(String text) {
    final value = int.tryParse(text);
    final error = value == null
        ? 'Nhập số nguyên'
        : value < widget.min || value > widget.max
            ? '${widget.min}–${widget.max} ${widget.unit}'
            : value % widget.step != 0
                ? 'Bội ${widget.step} ${widget.unit}'
                : null;
    setState(() => _error = error);
    widget.onValidationChanged?.call(error == null);
    if (error == null) {
      widget.onChanged(value!);
    }
  }

  void _change(int value) {
    _controller.text = '$value';
    setState(() => _error = null);
    widget.onValidationChanged?.call(true);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final step = widget.step;
    if (widget.editable) {
      final errorColor = Theme.of(context).colorScheme.error;
      return SizedBox(
        width: QuantityStepper.editableWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _btn(
                    Icons.remove,
                    widget.enabled && value - step >= widget.min
                        ? () => _change(value - step)
                        : null),
                Expanded(
                    child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _error == null ? null : errorColor),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                  onTap: () => _controller.selection = TextSelection(
                      baseOffset: 0, extentOffset: _controller.text.length),
                  onChanged: _input,
                  onSubmitted: (_) => _focus.unfocus(),
                  onTapOutside: (_) => _focus.unfocus(),
                )),
                _btn(
                    Icons.add,
                    widget.enabled && value + step <= widget.max
                        ? () => _change(value + step)
                        : null),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11)),
              ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _btn(
            Icons.remove,
            widget.enabled && value - step >= widget.min
                ? () => _change(value - step)
                : null),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _btn(
            Icons.add,
            widget.enabled && value + step <= widget.max
                ? () => _change(value + step)
                : null),
      ],
    );
  }

  // Compact circular outlined − / + buttons, as in the cart reference.
  Widget _btn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 36,
        height: 36,
        child: IconButton.outlined(
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            foregroundColor: AppColors.text,
            side: BorderSide(
                color: onTap == null ? AppColors.divider : AppColors.textMuted),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16),
        ),
      );
}
