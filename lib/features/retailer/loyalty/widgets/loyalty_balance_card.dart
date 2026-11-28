import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
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
          // Balance, followed by points held for rewards and expired points.
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: AppRadius.cardAll,
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${account.retailerCode} · ${account.retailerName}',
                  style: AppText.bodySmall.copyWith(
                      color: AppColors.warning, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${account.balance}',
                    style: AppText.display
                        .copyWith(fontSize: 36, color: AppColors.warning)),
              ),
              Text('điểm khả dụng',
                  style: AppText.bodyMedium.copyWith(color: AppColors.warning)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                  spacing: AppSpacing.xxl,
                  runSpacing: AppSpacing.md,
                  children: [
                    _Points('Đang giữ đổi quà', account.held),
                    _Points('Đã hết hạn', account.expired),
                  ]),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
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
              style: AppText.caption.copyWith(
                  color: AppColors.warning, fontWeight: FontWeight.w400)),
          Text('$points',
              style: AppText.strong
                  .copyWith(fontSize: 16, color: AppColors.warning)),
        ],
      );
}

class LoyaltyProgramCard extends StatelessWidget {
  const LoyaltyProgramCard({super.key, required this.account});
  final LoyaltyAccount account;

  @override
  Widget build(BuildContext context) {
    final programs = account.eligiblePrograms ??
        (account.program == null ? <LoyaltyProgram>[] : [account.program!]);
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            programs.isEmpty
                ? 'Chưa có chương trình trong kỳ hiện tại'
                : 'Chương trình tích điểm áp dụng',
            style: AppText.strong),
        for (final program in programs) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('${program.code} · ${program.name}', style: AppText.strong),
          KvRow('Quy đổi hiện tại',
              '${program.amountPerPoint.toString().replaceAll('.', ',')} VND = 1 điểm'),
          KvRow('Trạng thái', program.isActive ? 'Đã bật' : 'Đang tạm dừng'),
          KvRow('Hiệu lực từ', AppDates.timeDay(program.startAt)),
          KvRow('Hiệu lực đến', AppDates.timeDay(program.endAt)),
        ],
        KvRow(
            'Hạn điểm',
            account.pointsExpireAt == null
                ? 'Không đặt hạn'
                : AppDates.timeDay(account.pointsExpireAt)),
        const SizedBox(height: AppSpacing.sm),
        const Text('Điểm chỉ được cộng khi đơn Hoàn tất: nhận đủ hàng, '
            'thanh toán đủ và không còn khiếu nại đang xử lý. '
            'Số điểm làm tròn xuống theo máy chủ.'),
        const SizedBox(height: AppSpacing.sm),
        const Text('Quyền tích điểm được ghi nhận khi hệ thống nhận đơn. '
            'Chương trình hết hạn sau thời điểm đó không làm mất quyền lợi. '
            'Với đơn ngoại tuyến, thời điểm này là lúc gửi đồng bộ thành công.'),
        if (programs.isNotEmpty)
          const Text(
              'Mỗi đơn chỉ hưởng chương trình đủ điều kiện cho nhiều điểm nhất; '
              'bằng điểm thì ưu tiên mã chương trình tăng dần. Điểm vào ví chung. '
              'Điểm của đơn cũ theo tỷ lệ đã ghi nhận, không tính lại theo cấu hình mới.'),
        const SizedBox(height: AppSpacing.s6),
        const Text('Điểm đang giữ đổi quà chưa thể dùng để đổi thêm quà.'),
      ],
    ));
  }
}
