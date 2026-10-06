import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/domain/sales_models.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Khuyến mãi đang chạy')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.promotions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final promotion = controller.promotions[index];
          return FscmCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PromotionDetailScreen(promotion: promotion),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0DF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.sell_outlined,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${promotion.id} · ${promotion.name}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        promotion.validity,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FscmColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        promotion.description,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PromotionDetailScreen extends StatelessWidget {
  const PromotionDetailScreen({super.key, required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(promotion.id)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sell_outlined,
                  color: Color(0xFFB45309),
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  promotion.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  promotion.validity,
                  style: const TextStyle(color: FscmColors.muted),
                ),
                const Divider(height: 28),
                Text(
                  promotion.description,
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const FscmCard(
            color: Color(0xFFF2FAF7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: FscmColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ứng dụng hiển thị khuyến mãi dự kiến khi đặt offline. Hệ thống sẽ tính lại điều kiện khi đơn được đồng bộ.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final myOrders = controller.orders
        .where((order) => order.createdBy == 'Nguyễn Văn An')
        .toList();
    final revenue = myOrders
        .where(
          (order) =>
              order.status != SalesOrderStatus.rejected &&
              order.status != SalesOrderStatus.cancelled,
        )
        .fold<int>(0, (sum, order) => sum + order.total);
    final discount = myOrders.fold<int>(
      0,
      (sum, order) => sum + order.discount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Doanh số của tôi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text('Hôm nay'), selected: false),
              ChoiceChip(label: Text('7 ngày'), selected: false),
              ChoiceChip(label: Text('Tháng 9'), selected: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Đơn của tôi',
                  value: '${myOrders.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'KPI hoàn thành',
                  value: '86%',
                  valueColor: FscmColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doanh thu sau khuyến mãi',
                  style: TextStyle(color: FscmColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 5),
                Text(
                  formatVnd(revenue),
                  style: const TextStyle(
                    color: FscmColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã giảm ${formatVnd(discount)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: FscmColors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(
                  value: .86,
                  minHeight: 9,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Mục tiêu tháng: 120.000.000đ',
                  style: TextStyle(fontSize: 12, color: FscmColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Đơn gần đây'),
          const SizedBox(height: 8),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: myOrders
                  .take(5)
                  .map(
                    (order) => ListTile(
                      title: Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(order.retailer.name),
                      trailing: Text(
                        formatVnd(order.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _showProducts = false;

  static const _sales = [
    ('Trần Thị Bình', 'Q12-A', 245700000),
    ('Lê Minh Hoàng', 'Q12-B', 235200000),
    ('Phạm Thu Hà', 'Q12-B', 171400000),
    ('Nguyễn Văn An (bạn)', 'Q12-A', 158300000),
    ('Võ Quốc Huy', 'Q12-A', 150300000),
  ];

  static const _products = [
    ('Sữa chua có đường 100g', 'SKU001', 1240, 297800000),
    ('Sữa tươi tiệt trùng ít đường', 'SKU003', 980, 301900000),
    ('Sữa chua uống men sống', 'SKU002', 760, 155300000),
    ('Bánh mì sandwich lát', 'SKU005', 640, 179200000),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng xếp hạng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sales')),
              ButtonSegment(value: true, label: Text('Sản phẩm bán chạy')),
            ],
            selected: {_showProducts},
            onSelectionChanged: (value) =>
                setState(() => _showProducts = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          if (!_showProducts) ...[
            const FscmCard(
              color: Color(0xFFFFF7E6),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Color(0xFFB45309), size: 34),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Xếp hạng theo doanh thu sau khuyến mãi trong tháng 9.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._sales.indexed.map((entry) {
              final (index, sale) = entry;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FscmCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: index < 3
                                ? const Color(0xFFB45309)
                                : FscmColors.text,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        child: Text(sale.$1.split(' ').last.characters.first),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              sale.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FscmColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatVnd(sale.$3),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else
            ..._products.indexed.map((entry) {
              final (index, product) = entry;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FscmCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${product.$2} · ${product.$3} thùng',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: FscmColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatVnd(product.$4),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: product.$3 / _products.first.$3,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                        color: const Color(0xFFB85C1E),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class RetailerLeadsScreen extends StatefulWidget {
  const RetailerLeadsScreen({super.key});

  @override
  State<RetailerLeadsScreen> createState() => _RetailerLeadsScreenState();
}

class _RetailerLeadsScreenState extends State<RetailerLeadsScreen> {
  RetailerLeadStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final leads = controller.leads
        .where((lead) => _filter == null || lead.status == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khai báo retailer'),
        actions: [
          IconButton(
            tooltip: 'Khai báo mới',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RetailerLeadFormScreen(),
              ),
            ),
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Chờ duyệt'),
                  selected: _filter == RetailerLeadStatus.pending,
                  onSelected: (_) =>
                      setState(() => _filter = RetailerLeadStatus.pending),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Đã duyệt'),
                  selected: _filter == RetailerLeadStatus.approved,
                  onSelected: (_) =>
                      setState(() => _filter = RetailerLeadStatus.approved),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Bị từ chối'),
                  selected: _filter == RetailerLeadStatus.rejected,
                  onSelected: (_) =>
                      setState(() => _filter = RetailerLeadStatus.rejected),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: leads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _LeadCard(lead: leads[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RetailerLeadFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Khai báo mới'),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});

  final RetailerLead lead;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (lead.status) {
      RetailerLeadStatus.pending => (
        'Chờ duyệt',
        FscmColors.info,
        const Color(0xFFE8EEFD),
      ),
      RetailerLeadStatus.approved => (
        'Đã duyệt',
        FscmColors.primary,
        const Color(0xFFE1F1EC),
      ),
      RetailerLeadStatus.rejected => (
        'Bị từ chối',
        FscmColors.danger,
        const Color(0xFFFDECEA),
      ),
    };
    return FscmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lead.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            lead.address,
            style: const TextStyle(color: FscmColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 7),
          Text(
            '${lead.retailerCode ?? lead.id} · Tiềm năng ${lead.potentialClass} · ${lead.contact}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (lead.reason case final reason?) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(color: FscmColors.danger, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class RetailerLeadFormScreen extends StatefulWidget {
  const RetailerLeadFormScreen({super.key});

  @override
  State<RetailerLeadFormScreen> createState() => _RetailerLeadFormScreenState();
}

class _RetailerLeadFormScreenState extends State<RetailerLeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  String _potentialClass = 'B';

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khai báo retailer mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Tên điểm bán'),
            const SizedBox(height: 12),
            _field(_address, 'Địa chỉ'),
            const SizedBox(height: 12),
            _field(_contact, 'Người liên hệ'),
            const SizedBox(height: 12),
            _field(_phone, 'Số điện thoại', keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            const SectionTitle('Đánh giá tiềm năng'),
            const SizedBox(height: 8),
            const Text(
              'Phân loại dựa trên quy mô cửa hàng, doanh thu dự kiến và khả năng nhập hàng.',
              style: TextStyle(
                color: FscmColors.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'A', label: Text('A · Cao')),
                ButtonSegment(value: 'B', label: Text('B · Khá')),
                ButtonSegment(value: 'C', label: Text('C · Cơ bản')),
              ],
              selected: {_potentialClass},
              onSelectionChanged: (value) =>
                  setState(() => _potentialClass = value.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Gửi khai báo để duyệt'),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Vui lòng nhập $label' : null,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    SalesScope.of(context, listen: false).addRetailerLead(
      name: _name.text.trim(),
      address: _address.text.trim(),
      contact: _contact.text.trim(),
      phone: _phone.text.trim(),
      potentialClass: _potentialClass,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi khai báo retailer để duyệt.')),
    );
  }
}
