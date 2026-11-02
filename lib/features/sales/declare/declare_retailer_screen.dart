import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// "Khai báo retailer mới" (`POST /retailers`) or edit of a Draft / Rejected
/// declaration (`PUT /retailers/{id}/declaration`). Sales can save a draft or
/// submit for Admin / Operator review; submitting needs at least one MLOR.
class DeclareRetailerScreen extends ConsumerStatefulWidget {
  const DeclareRetailerScreen({super.key, this.initial});

  /// Declaration being edited; null when creating a new one.
  final RetailerDeclaration? initial;

  @override
  ConsumerState<DeclareRetailerScreen> createState() =>
      _DeclareRetailerScreenState();
}

class _DeclareRetailerScreenState extends ConsumerState<DeclareRetailerScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _area;
  late final TextEditingController _forecast;
  late final TextEditingController _capacity;
  late final TextEditingController _frequency;
  late final TextEditingController _note;
  late RetailerTypeOption _type;
  late int _creditTerm;
  late List<MlorDeclaration> _mlors;
  String? _salesGroupId;
  bool _busy = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    String num(double v) => v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    _name = TextEditingController(text: d?.name ?? '');
    _address = TextEditingController(text: d?.address ?? '');
    _contact = TextEditingController(text: d?.contactName ?? '');
    _phone = TextEditingController(text: d?.phone ?? '');
    _email = TextEditingController(text: d?.email ?? '');
    _area = TextEditingController(
        text: d == null ? '' : num(d.storeSizeSquareMeters));
    _forecast = TextEditingController(
        text: d == null || d.forecastRevenue == 0
            ? ''
            : d.forecastRevenue.round().toString());
    _capacity =
        TextEditingController(text: d == null ? '' : num(d.purchasingCapacity));
    _frequency = TextEditingController(
        text: d == null ? '4' : d.purchaseFrequencyPerMonth.toString());
    _note = TextEditingController(text: d?.assessmentNote ?? '');
    _type = d?.retailerType ?? RetailerTypeOption.groceryStore;
    _creditTerm = allowedCreditTermDays.contains(d?.requestedCreditTermDays)
        ? d!.requestedCreditTermDays
        : 0;
    _mlors = List<MlorDeclaration>.of(d?.mlorDeclarations ?? const []);
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _address,
      _contact,
      _phone,
      _email,
      _area,
      _forecast,
      _capacity,
      _frequency,
      _note
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String _digits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

  static double? _decimal(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  RetailerDeclarationInput _input({required bool submit}) =>
      RetailerDeclarationInput(
        name: _name.text.trim(),
        contactName: _contact.text.trim(),
        phone: _digits(_phone.text),
        email: _email.text.trim().toLowerCase(),
        address: _address.text.trim(),
        retailerType: _type,
        forecastRevenue: (Money.parse(_forecast.text) ?? 0).toDouble(),
        storeSizeSquareMeters: _decimal(_area.text) ?? 0,
        purchasingCapacity: _decimal(_capacity.text) ?? 0,
        purchaseFrequencyPerMonth: int.tryParse(_frequency.text.trim()) ?? 0,
        requestedCreditTermDays: _creditTerm,
        assessmentNote: _note.text.trim(),
        mlorDeclarations: _mlors,
        submitForReview: submit,
      );

  Future<void> _save({required bool submit}) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (submit && _mlors.isEmpty) {
      showAppSnack(
          context, 'Cần ít nhất 1 MLOR (ngành hàng hoặc SKU) để gửi duyệt.',
          error: true);
      return;
    }
    final repo = ref.read(retailerRepositoryProvider);
    setState(() => _busy = true);
    try {
      final RetailerDeclaration result;
      if (_isEdit) {
        result = await repo.update(widget.initial!.id, _input(submit: submit));
      } else {
        final territories = await ref.read(salesTerritoriesProvider.future);
        final territory = territories.firstWhere(
            (t) => t.salesGroupId == _salesGroupId,
            orElse: () => territories.first);
        result = await repo.declare(_input(submit: submit), territory);
      }
      ref.read(dataVersionProvider.notifier).state++;
      if (!mounted) return;
      showAppSnack(
          context,
          submit
              ? 'Đã gửi khai báo ${result.code}. Chờ Admin / Operator duyệt.'
              : 'Đã lưu nháp ${result.code}.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } on StateError {
      if (mounted) {
        showAppSnack(context, 'Tài khoản chưa được gán nhóm Sales nào.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMlor() async {
    final entry = await showModalBottomSheet<MlorDeclaration>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MlorEditor(
        existing: _mlors,
      ),
    );
    if (entry != null) {
      setState(() => _mlors = <MlorDeclaration>[..._mlors, entry]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final territories = ref.watch(salesTerritoriesProvider);
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit
              ? 'Sửa khai báo ${initial!.code}'
              : 'Khai báo retailer mới')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            const InfoBanner(
              text:
                  'Gửi Admin / Operator duyệt. Sau khi duyệt, hệ thống cấp mã điểm bán 8 chữ số và tạo tài khoản Retailer App, email thông báo được gửi tới địa chỉ bên dưới.',
            ),
            if (initial?.status == DeclarationStatus.rejected &&
                initial!.reviewReason.isNotEmpty)
              InfoBanner(
                  tone: StatusTone.danger,
                  title: 'Lý do từ chối',
                  text: initial.reviewReason),
            if (!_isEdit) _territoryField(territories),
            const SectionTitle('Thông tin điểm bán'),
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên điểm bán'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Tên điểm bán tối thiểu 2 ký tự'
                    : null),
            const SizedBox(height: 10),
            TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                validator: (v) => _required(v, 'Nhập địa chỉ')),
            const SizedBox(height: 10),
            TextFormField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Người liên hệ'),
                validator: (v) => _required(v, 'Nhập người liên hệ')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  helperText: 'Dùng để Retailer đăng nhập lần đầu'),
              validator: (v) {
                final d = _digits(v ?? '');
                return d.length == 10 && d.startsWith('0')
                    ? null
                    : 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0';
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Nhận thông báo tạo tài khoản và mã OTP'),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch((v ?? '').trim())
                  ? null
                  : 'Nhập email hợp lệ',
            ),
            const SectionTitle('Đánh giá tiềm năng'),
            DropdownButtonFormField<RetailerTypeOption>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại hình'),
              items: RetailerTypeOption.values
                  .map((t) => DropdownMenuItem<RetailerTypeOption>(
                      value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _area,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Diện tích (m²)',
                        helperText: '<30 S · 30–60 M · >60 L'),
                    validator: (v) => (_decimal(v ?? '') ?? 0) > 0
                        ? null
                        : 'Nhập diện tích > 0',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _frequency,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Số lần nhập / tháng',
                        helperText: '1 lần/tuần ≈ 4'),
                    validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0
                        ? null
                        : 'Nhập số > 0',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _forecast,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Doanh thu dự báo / tháng (đ)'),
              validator: (v) =>
                  Money.parse(v ?? '') == null ? 'Nhập doanh thu dự báo' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _capacity,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Khả năng nhập hàng (thùng / tháng)'),
              validator: (v) => (_decimal(v ?? '') ?? -1) >= 0
                  ? null
                  : 'Nhập khả năng nhập hàng',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _creditTerm,
              decoration: const InputDecoration(
                  labelText: 'Đề xuất hạn thanh toán',
                  helperText: 'Admin quyết định khi duyệt'),
              items: allowedCreditTermDays
                  .map((d) => DropdownMenuItem<int>(
                      value: d, child: Text(d == 0 ? 'Trả ngay' : '$d ngày')))
                  .toList(),
              onChanged: (v) => setState(() => _creditTerm = v ?? _creditTerm),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Ghi chú đánh giá',
                  hintText: 'Số tủ mát, vị trí, đối thủ gần đó...'),
            ),
            SectionTitle('MLOR (hạn dùng còn lại tối thiểu)',
                trailing: TextButton.icon(
                    onPressed: _busy ? null : _addMlor,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm'))),
            if (_mlors.isEmpty)
              const InfoBanner(
                  tone: StatusTone.warning,
                  text:
                      'Chưa có MLOR. Có thể lưu nháp, nhưng cần ít nhất 1 dòng để gửi duyệt.'),
            for (var i = 0; i < _mlors.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_mlors[i].isSku
                    ? Icons.qr_code_2_outlined
                    : Icons.category_outlined),
                title: Text(_mlors[i].label.isEmpty
                    ? (_mlors[i].isSku ? 'SKU' : 'Ngành hàng')
                    : _mlors[i].label),
                subtitle: Text(
                    'Tối thiểu ${(_mlors[i].minimumLifeRatio * 100).round()}% hạn dùng'
                    '${_mlors[i].minimumLifeHours == null ? '' : ' · ${_mlors[i].minimumLifeHours} giờ'}'),
                trailing: IconButton(
                  tooltip: 'Xóa MLOR',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _mlors =
                          List<MlorDeclaration>.of(_mlors)..removeAt(i)),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                      onPressed: _busy ? null : () => _save(submit: false),
                      child: const Text('Lưu nháp')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                      onPressed: _busy ? null : () => _save(submit: true),
                      child: Text(_busy ? 'Đang gửi...' : 'Gửi duyệt')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _territoryField(AsyncValue<List<SalesTerritory>> territories) =>
      territories.when(
        loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator()),
        error: (e, _) => InfoBanner(
            tone: StatusTone.danger,
            title: 'Không tải được nhóm Sales',
            text: ApiException.describe(e)),
        data: (list) {
          if (list.isEmpty) {
            return const InfoBanner(
                tone: StatusTone.danger,
                text:
                    'Tài khoản chưa được gán nhóm Sales nào nên chưa khai báo được retailer.');
          }
          _salesGroupId ??= list.first.salesGroupId;
          return DropdownButtonFormField<String>(
            initialValue: _salesGroupId,
            decoration:
                const InputDecoration(labelText: 'Nhóm Sales · khu vực'),
            items: list
                .map((t) => DropdownMenuItem<String>(
                    value: t.salesGroupId, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _salesGroupId = v),
          );
        },
      );
}

/// Bottom sheet that builds one MLOR entry (Category or SKU scope).
class _MlorEditor extends ConsumerStatefulWidget {
  const _MlorEditor({required this.existing});

  final List<MlorDeclaration> existing;

  @override
  ConsumerState<_MlorEditor> createState() => _MlorEditorState();
}

class _MlorEditorState extends ConsumerState<_MlorEditor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _percent = TextEditingController(text: '60');
  final TextEditingController _hours = TextEditingController();
  bool _sku = false;
  MlorScopeOption? _option;

  @override
  void dispose() {
    _percent.dispose();
    _hours.dispose();
    super.dispose();
  }

  bool _duplicate(MlorScopeOption o) => widget.existing
      .any((e) => _sku ? e.productId == o.id : e.productCategoryId == o.id);

  void _confirm() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final o = _option!;
    Navigator.of(context).pop(MlorDeclaration(
      productCategoryId: _sku ? null : o.id,
      productId: _sku ? o.id : null,
      minimumLifeRatio: int.parse(_percent.text.trim()) / 100,
      minimumLifeHours: _sku && _hours.text.trim().isNotEmpty
          ? int.parse(_hours.text.trim())
          : null,
      label: '${_sku ? 'SKU' : 'Ngành hàng'} ${o.label}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(_sku ? mlorProductsProvider : mlorCategoriesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Thêm MLOR',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Ngành hàng')),
                ButtonSegment<bool>(value: true, label: Text('SKU')),
              ],
              selected: <bool>{_sku},
              onSelectionChanged: (s) => setState(() {
                _sku = s.first;
                _option = null;
              }),
            ),
            const SizedBox(height: 12),
            options.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(ApiException.describe(e),
                  style: const TextStyle(color: Color(0xFFB42318))),
              data: (list) => DropdownButtonFormField<MlorScopeOption>(
                key: ValueKey<bool>(_sku),
                isExpanded: true,
                initialValue: _option,
                decoration: InputDecoration(
                    labelText: _sku ? 'Chọn SKU' : 'Chọn ngành hàng'),
                items: list
                    .map((o) => DropdownMenuItem<MlorScopeOption>(
                        value: o,
                        child: Text(o.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _option = v),
                validator: (v) {
                  if (v == null) return 'Chọn phạm vi áp dụng';
                  if (_duplicate(v)) return 'Phạm vi này đã có MLOR';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _percent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Hạn dùng còn lại tối thiểu (%)',
                  helperText: 'Từ 1 đến 99'),
              validator: (v) {
                final p = int.tryParse((v ?? '').trim());
                return p != null && p > 0 && p < 100 ? null : 'Nhập 1–99';
              },
            ),
            if (_sku) ...<Widget>[
              const SizedBox(height: 10),
              TextFormField(
                controller: _hours,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Số giờ tối thiểu (không bắt buộc)',
                    helperText: _option?.shelfLifeHours == null
                        ? null
                        : 'Tối đa ${_option!.shelfLifeHours} giờ'),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final h = int.tryParse(v!.trim());
                  final max = _option?.shelfLifeHours;
                  if (h == null || h < 0) return 'Nhập số giờ hợp lệ';
                  if (max != null && h > max) return 'Không vượt quá $max giờ';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _confirm, child: const Text('Thêm MLOR')),
          ],
        ),
      ),
    );
  }
}
