import 'package:flutter/material.dart';

String _searchText(String value) {
  var result = value.toLowerCase();
  const groups = <String, String>{
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };
  for (final entry in groups.entries) {
    result = result.replaceAll(RegExp('[${entry.key}]'), entry.value);
  }
  return result;
}

/// Search a code/name label while submitting only an existing catalog item.
class SearchPickerField<T> extends StatelessWidget {
  const SearchPickerField(
      {super.key,
      required this.label,
      required this.options,
      required this.labelOf,
      required this.onChanged,
      this.initialValue,
      this.validator});
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T? initialValue;
  final ValueChanged<T> onChanged;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => FormField<T>(
        initialValue: initialValue,
        validator: validator,
        builder: (field) => InkWell(
          onTap: () async {
            final selected = await showModalBottomSheet<T>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => _SearchSheet<T>(
                  label: label, options: options, labelOf: labelOf),
            );
            if (selected != null && context.mounted) {
              field.didChange(selected);
              onChanged(selected);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: label,
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.search)),
            child: Text(
                field.value == null
                    ? 'Tìm theo mã hoặc tên'
                    : labelOf(field.value as T),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet(
      {required this.label, required this.options, required this.labelOf});
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.options
        .where(
            (o) => _searchText(widget.labelOf(o)).contains(_searchText(query)))
        .toList();
    return FractionallySizedBox(
        heightFactor: .85,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(widget.label,
                      style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'))
            ]),
            TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Nhập mã hoặc tên sản phẩm',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => query = v)),
            const SizedBox(height: 8),
            Expanded(
                child: matches.isEmpty
                    ? const Center(child: Text('Không tìm thấy kết quả.'))
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) => ListTile(
                            title: Text(widget.labelOf(matches[index])),
                            onTap: () =>
                                Navigator.pop(context, matches[index])),
                      )),
          ]),
        ));
  }
}
