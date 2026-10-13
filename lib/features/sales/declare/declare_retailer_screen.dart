import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// "Khai báo retailer mới" with potential-assessment fields; submitting
/// creates a KB-0000 request for Admin / Operator approval (needs network).
class DeclareRetailerScreen extends ConsumerStatefulWidget {
  const DeclareRetailerScreen({super.key});

  @override
  ConsumerState<DeclareRetailerScreen> createState() =>
      _DeclareRetailerScreenState();
}

class _DeclareRetailerScreenState extends ConsumerState<DeclareRetailerScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _fridges = TextEditingController();
  final TextEditingController _forecast = TextEditingController();
  final TextEditingController _capacity = TextEditingController();
  String _kind = 'Tạp hóa';
  String _size = 'S';
  String _frequency = '1 lần/tuần';
  bool _busy = false;

  static const List<String> _kinds = <String>[
    'Tạp hóa',
    'Siêu thị mini',
    'Cửa hàng tiện lợi',
    'Quán / căn tin'
  ];
  static const List<String> _frequencies = <String>[
    '1 lần/tuần',
    '2 lần/tuần',
    '3 lần/tuần',
    'Hằng ngày'
  ];

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _address,
      _contact,
      _phone,
      _area,
      _fridges,
      _forecast,
      _capacity
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final reg = await ref.read(retailerRepositoryProvider).declare(
            NewRegistration(
              name: _name.text.trim(),
              address: _address.text.trim(),
              contactName: _contact.text.trim(),
              phone: _phone.text.trim(),
              potential: RetailerPotential(
                kind: _kind,
                size: _size,
                areaM2: int.tryParse(_area.text.trim()) ?? 0,
                fridges: int.tryParse(_fridges.text.trim()) ?? 0,
                forecastRevenue: Money.parse(_forecast.text) ?? 0,
                capacityCases: int.tryParse(_capacity.text.trim()) ?? 0,
                frequency: _frequency,
              ),
            ),
          );
      ref.read(dataVersionProvider.notifier).state++;
      if (!mounted) return;
      showAppSnack(
          context, 'Đã gửi khai báo ${reg.code}. Chờ Admin / Operator duyệt.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khai báo retailer mới')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            InfoBanner(
              text:
                  'Gửi Admin / Operator duyệt. Sau khi duyệt, hệ thống cấp mã điểm bán 8 chữ số (theo mã khách hàng SAP) và tài khoản Retailer App. Khu vực: ${user?.areaName ?? ''}.',
            ),
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên điểm bán'),
                validator: (v) => _required(v, 'Nhập tên điểm bán')),
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
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: (v) => (v == null || v.replaceAll(' ', '').length < 9)
                  ? 'Nhập số điện thoại hợp lệ'
                  : null,
            ),
            const SectionTitle('Đánh giá tiềm năng'),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Loại hình'),
              items: _kinds
                  .map(
                      (k) => DropdownMenuItem<String>(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _size,
              decoration: const InputDecoration(labelText: 'Quy mô cửa hàng'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'S', child: Text('S - nhỏ')),
                DropdownMenuItem<String>(value: 'M', child: Text('M - vừa')),
                DropdownMenuItem<String>(value: 'L', child: Text('L - lớn')),
              ],
              onChanged: (v) => setState(() => _size = v ?? _size),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                    child: TextFormField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Diện tích (m²)'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        controller: _fridges,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Số tủ mát'))),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
                controller: _forecast,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Doanh thu dự báo / tháng (đ)')),
            const SizedBox(height: 10),
            TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Khả năng nhập hàng (thùng / tháng)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration:
                  const InputDecoration(labelText: 'Tần suất nhập hàng'),
              items: _frequencies
                  .map(
                      (k) => DropdownMenuItem<String>(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v ?? _frequency),
            ),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Đang gửi...' : 'Gửi khai báo')),
          ],
        ),
      ),
    );
  }
}
