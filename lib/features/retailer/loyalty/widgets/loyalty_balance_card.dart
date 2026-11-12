import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

class LoyaltyBalanceCard extends StatelessWidget {
  const LoyaltyBalanceCard({super.key, required this.account});
  final LoyaltyAccount account;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${account.retailerCode} · ${account.retailerName}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Text('${account.balance}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800)),
              const Text('điểm khả dụng',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Wrap(spacing: 24, runSpacing: 12, children: [
                _Points('Chờ cộng', account.pending),
                _Points('Đang giữ đổi quà', account.held),
                _Points('Đã hết hạn', account.expired),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (account.hasNegativeBalance)
            const InfoBanner(
                tone: StatusTone.warning,
                title: 'Số dư điểm đang âm',
                text:
                    'Điểm có thể giảm sau điều chỉnh giá trị đơn hoặc hoàn tiền. '
                    'Hãy xem lý do trong sổ điểm. Bạn chưa thể gửi yêu cầu đổi quà mới khi số dư âm.'),
        ],
      );
}

class _Points extends StatelessWidget {
  const _Points(this.label, this.points);
  final String label;
  final int points;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$points',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class LoyaltyProgramCard extends StatelessWidget {
  const LoyaltyProgramCard({super.key, required this.account});
  final LoyaltyAccount account;

  @override
  Widget build(BuildContext context) {
    final program = account.program;
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            program == null
                ? 'Chưa có chương trình trong kỳ hiện tại'
                : '${program.code} · ${program.name}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        if (program != null) ...[
          KvRow('Quy đổi hiện tại',
              '${program.amountPerPoint.toString().replaceAll('.', ',')} đồng = 1 điểm'),
          KvRow('Trạng thái', program.isActive ? 'Đã bật' : 'Đang tạm dừng'),
          KvRow('Hiệu lực từ', AppDates.timeDay(program.startAt)),
          KvRow('Hiệu lực đến', AppDates.timeDay(program.endAt)),
        ],
        KvRow(
            'Hạn điểm',
            account.pointsExpireAt == null
                ? 'Không đặt hạn'
                : AppDates.timeDay(account.pointsExpireAt)),
        const SizedBox(height: 8),
        const Text('Điểm chỉ được cộng khi đơn Completed: nhận đủ hàng, '
            'thanh toán đủ và không còn khiếu nại đang xử lý. '
            'Số điểm làm tròn xuống theo máy chủ.'),
        if (program != null)
          const Text(
              'Tỷ lệ trên là cấu hình hiện tại. Điểm của đơn cũ theo tỷ lệ '
              'đã ghi nhận, không tính lại theo cấu hình mới.'),
        const SizedBox(height: 6),
        const Text(
            'Điểm chờ cộng và điểm đang giữ đổi quà chưa thể dùng để đổi thêm quà.'),
      ],
    ));
  }
}
