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
  Offset? _lastPointerPosition;
  bool _isHorizontalDrag = false;

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

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.position;
    _isHorizontalDrag = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final lastPosition = _lastPointerPosition;
    if (lastPosition == null) return;
    final delta = event.position - lastPosition;
    if (!_isHorizontalDrag && delta.dx.abs() > delta.dy.abs()) {
      _isHorizontalDrag = true;
    }
    if (_isHorizontalDrag && _scrollController.hasClients) {
      final position = _scrollController.position;
      _scrollController.jumpTo(
        (position.pixels - delta.dx)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    _lastPointerPosition = event.position;
  }

  void _resetPointer(PointerEvent _) {
    _lastPointerPosition = null;
    _isHorizontalDrag = false;
  }

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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _resetPointer,
        onPointerCancel: _resetPointer,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
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
