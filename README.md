# FSCM Mobile – Flutter (một app, theo vai trò)

App cho **Sales**, **Warehouse Keeper** và **Retailer** (FA26SE083 · GFA26SE63). Vai trò lấy theo tài khoản đăng nhập; mỗi vai trò có shell và thanh điều hướng riêng (nút Quét QR ở giữa, chuông thông báo góc phải).

## Chạy lần đầu

Repo chỉ chứa `lib/`, `test/`, `pubspec.yaml`. Thư mục nền tảng sinh bằng Flutter:

```bash
flutter create . --org vn.edu.fpt.fscm --platforms android,ios --project-name fscm_mobile
flutter pub get
flutter run                     # mặc định USE_MOCK=true: chạy không cần backend, dữ liệu mẫu prototype
flutter test
```

Sau `flutter create`, thêm quyền camera cho `mobile_scanner`:
- Android `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA" />`, và `minSdkVersion 21` trong `android/app/build.gradle`.
- iOS `ios/Runner/Info.plist`: `NSCameraUsageDescription` = "Quét mã QR tem hàng / nhận hàng".

Tài khoản mock (mật khẩu `Fscm2026`):

| Vai trò | Số điện thoại | Người dùng |
|---|---|---|
| Sales | 0909123456 | Nguyễn Văn An – Quận 12, nhóm Q12-A |
| Warehouse Keeper | 0912440118 | Đỗ Văn Tâm – Kho Thới An |
| Retailer | 0909555127 | Tạp hóa Minh Châu (10004127) |

Nối backend thật:
```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:5080/api/v1
```
(`10.0.2.2` = máy host khi chạy Android emulator.)

## Cấu trúc

```
lib/
├─ main.dart              ProviderScope; USE_MOCK=true thì thay transport bằng MockApi
├─ app/                   FscmApp, router (go_router, redirect theo vai trò), theme, shell/ (sales, warehouse, retailer)
├─ core/                  auth (session, role), config (env, device identity → mã OFF-{device}), network (dio client, ApiException từ ProblemDetails, transport, endpoints, network monitor), storage (token), utils (id_format, money, dates, clock)
├─ data/
│  ├─ models/             DTO + enum (trạng thái đơn, thanh toán COD / trả trước / công nợ 7-14-30, phiếu điều chuyển Bổ sung / Luân chuyển cận hạn…)
│  ├─ remote/             *_api.dart – một file mỗi nhóm REST
│  ├─ local/              sqflite: AppDatabase + DAO (retailer, product, promotion, inventory snapshot, sync state, offline order queue)
│  ├─ pricing/            tính khuyến mãi tạm trên máy khi offline (server tính lại khi sync)
│  ├─ repositories/       ghép remote + local cho từng nghiệp vụ
│  └─ mock/               MockApi trong app (seed = dữ liệu prototype)
├─ sync/                  SyncService + sync_queue_logic (thứ tự tạo, retry, idempotency clientRequestId UUID)
├─ shared/                routes, theme màu, widget dùng chung (status chip, QR scan view, timeline, stepper…)
└─ features/
   ├─ common/             splash, login, thông báo, hồ sơ
   ├─ sales/              home, retailer trong vùng (chặn trái vùng), sản phẩm + khuyến mãi, tạo đơn (offline), xác nhận (thanh toán, công nợ nếu retailer được phép), màn Đồng bộ 3 tab Chưa / Đang / Đã, chi tiết đơn, công nợ của tôi (lọc quá hạn), KPI & xếp hạng sau KM + sản phẩm bán chạy, khai báo retailer mới (thông tin tiềm năng → KB)
   ├─ warehouse/          home, picking list, quét tem để soạn, chia số lượng, tra tem, nhận phiếu điều chuyển (cả loại Luân chuyển cận hạn)
   └─ retailer/           đơn hàng (đang / lịch sử, tên sản phẩm), chi tiết đơn có xe + người giao, quét QR nhận hàng → xác nhận + cộng điểm, thanh toán & công nợ, thẻ loyalty + sổ điểm, đổi quà (điểm tạm giữ), khiếu nại
```

Luồng offline của Sales: đơn lưu vào bảng `offline_order_queue` (clientRequestId UUID, payload, status, retryCount, error). Khi có mạng, `SyncService` gửi theo thứ tự tạo lên `POST /orders/sync`; kết quả server là cuối cùng (đơn tới sau không còn đủ hàng bị từ chối và báo cho Sales + retailer).

## Lưu ý khi nối API thật

- Mock đang có `POST /auth/password` (đăng nhập bằng số điện thoại + mật khẩu). Backend dùng Microsoft Entra ID, nên khi nối thật cần chọn một trong hai: thêm `msal_flutter`/`flutter_appauth` lấy token Entra, hoặc thêm endpoint đăng nhập vào module Identity của backend.
- Model trong `data/models` khớp với mock; đối chiếu lại với Swagger của backend và sửa một phía cho thống nhất.
- Thời gian gửi lên server phải là ISO 8601 có `Z` hoặc offset (Npgsql từ chối DateTime không rõ múi giờ).
- Chưa chạy `flutter analyze` trong môi trường tạo code (không có Flutter SDK); đã rà tĩnh toàn bộ import, constructor, API package. Chạy `flutter analyze` sau `flutter pub get` để chắc chắn.
