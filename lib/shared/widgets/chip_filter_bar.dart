import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

class ChipOption<T> {
  const ChipOption(this.value, this.label);
  final T value;
  final String label;
}

/// Horizontal single-select filter chips ("Tất cả / Chờ duyệt / ...").
class ChipFilterBar<T> extends StatefulWidget {
  const ChipFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.wrap = false,
  });

  final List<ChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final bool wrap;

  @override
  State<ChipFilterBar<T>> createState() => _ChipFilterBarState<T>();
}

class _ChipFilterBarState<T> extends State<ChipFilterBar<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _chips() =>
      List<Widget>.generate(widget.options.length, (index) {
        final option = widget.options[index];
        return _FilterChip(
          option: option,
          selected: option.value == widget.selected,
          onSelected: widget.onSelected,
        );
      });

  @override
  Widget build(BuildContext context) {
    if (widget.wrap) {
      return Padding(
        padding: widget.padding,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chips(),
        ),
      );
    }
    final chips = _chips();
    return SizedBox(
      height: 44,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: false,
        trackVisibility: false,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          primary: false,
          dragStartBehavior: DragStartBehavior.down,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < chips.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                chips[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final ChipOption<T> option;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(option.label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) => onSelected(option.value),
      );
}
