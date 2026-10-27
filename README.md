# FSCM Mobile – Flutter (một app, theo vai trò)

App cho **Sales**, **Warehouse Keeper** và **Retailer** (FA26SE083 · GFA26SE63). Vai trò lấy theo tài khoản đăng nhập; mỗi vai trò có shell và thanh điều hướng riêng (nút Quét QR ở giữa, chuông thông báo góc phải).

## Chạy lần đầu

Nếu checkout không có thư mục nền tảng, sinh lại bằng Flutter; repo hiện tại đã có các thư mục này nên thông thường chỉ cần `flutter pub get`:

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

## Kiến trúc và cấu trúc thư mục

Ứng dụng dùng kiến trúc phân lớp hướng feature: `features` chỉ lo presentation theo vai trò, `data` sở hữu DTO/remote/local/repository, `core` cung cấp hạ tầng kỹ thuật, và `sync` điều phối offline queue. Riverpod là dependency injection + state management; UI không tự tạo API client/database.

```
lib/
├─ main.dart              bootstrap Flutter/SharedPreferences; mock mode override ApiTransport
├─ app/
│  ├─ app.dart            MaterialApp.router và app-level configuration
│  ├─ router.dart         go_router, auth redirect, route theo vai trò
│  ├─ theme.dart          Material theme
│  └─ shell/              navigation shell riêng cho Sales/WK/Retailer
├─ core/
│  ├─ auth/               session state và role
│  ├─ config/             env, timeout, device identity → OFF-{device}
│  ├─ network/            ApiTransport, Dio ApiClient, endpoint, ProblemDetails, connectivity
│  ├─ storage/            secure token persistence
│  └─ utils/              hàm thuần id/money/date/clock/status tone
├─ data/
│  ├─ models/             DTO/enum + JSON mapping, không gọi network/database
│  ├─ remote/             API adapter theo resource; chỉ request/response mapping
│  ├─ local/              AppDatabase, DAO, cache snapshot và offline queue
│  ├─ pricing/            tính giá tạm offline; server vẫn authoritative
│  ├─ repositories/       facade nghiệp vụ kết hợp remote/local/mock và expose providers
│  └─ mock/               ApiTransport in-process có cùng contract với REST
├─ sync/
│  ├─ sync_service.dart   lấy queue, gửi tuần tự, ghi kết quả server
│  └─ sync_queue_logic.dart hàm thuần cho ordering/retry, dễ unit test
├─ shared/
│  ├─ routes.dart         hằng số route duy nhất
│  ├─ theme/              token màu dùng chung
│  └─ widgets/            widget tái sử dụng, không phụ thuộc một feature cụ thể
└─ features/
   ├─ common/             màn dùng chung: splash, login, notification, profile
   ├─ sales/              presentation cho Sales, chia tiếp theo luồng nghiệp vụ
   ├─ warehouse/          presentation cho Warehouse Keeper
   └─ retailer/           presentation cho Retailer
```

Luồng phụ thuộc chuẩn:

```text
screen/widget → Riverpod repository/provider → remote API → ApiClient → ApiTransport
                                    ├──────→ local DAO → SQLite
                                    └──────→ pricing/offline logic

main.dart chỉ thay ApiTransport thật bằng MockApi; các tầng phía trên không đổi
```

### Quy tắc khi implement thêm

- Screen chỉ render, giữ state giao diện ngắn hạn và gọi provider/repository. Không gọi Dio, SQL hay `MockApi` trực tiếp từ `features`.
- `data/remote` không chứa state UI hoặc offline policy; repository là nơi quyết định đọc remote, fallback local, merge cache và invalidation.
- Model parse JSON ở `data/models`; tránh truyền `dynamic` qua repository boundary. Field/date/status phải giữ đúng contract backend.
- Mọi HTTP thật đi qua `ApiClient`/`ApiTransport` để Bearer token, ProblemDetails và `401` có một cách xử lý thống nhất.
- Mock phải implement cùng path, body và response với backend. Không thêm endpoint chỉ có trong mock rồi để UI phụ thuộc vào nó.
- Command offline phải có UUID ổn định, thứ tự tạo, retry count và trạng thái rõ ràng. Retry cùng thao tác phải giữ cùng idempotency key; `409` cần tải lại version, không retry mù.
- Logic thuần (ordering, pricing tạm, formatter) tách khỏi widget để unit test. Kết quả pricing/allocation cuối cùng luôn lấy từ server sau sync.
- Route mới được khai báo ở `shared/routes.dart`, ghép vào đúng role branch trong `app/router.dart`; redirect theo role là UX guard, backend vẫn enforce quyền/scope.
- Widget chỉ đưa vào `shared/widgets` khi không mang ngữ nghĩa riêng của Sales/WK/Retailer; nếu có, đặt cạnh feature sử dụng.
- Khi thêm GraphQL, đặt client ở `core/network`, adapter ở `data/remote`, repository quyết định cache. GraphQL chỉ đọc; mọi create/update/scan/approve tiếp tục dùng REST theo backend hiện tại.

### Cách thêm một luồng mới

1. Tạo/cập nhật typed model và enum trong `data/models`.
2. Thêm remote adapter; nếu cần offline, thêm migration/DAO và quy tắc sync tương ứng.
3. Mở rộng repository/provider để che giấu nguồn dữ liệu khỏi UI.
4. Tạo screen/widget dưới đúng role/feature và đăng ký route.
5. Cập nhật MockApi với cùng contract để `USE_MOCK=true` vẫn chạy qua toàn bộ stack.
6. Viết unit test cho logic thuần/repository quan trọng; chạy `dart format`, `flutter analyze`, `flutter test`.

Luồng offline của Sales: đơn lưu vào bảng `offline_order_queue` (clientRequestId UUID, payload, status, retryCount, error). Khi có mạng, `SyncService` gửi theo thứ tự tạo và lấy kết quả server làm cuối cùng. Lưu ý contract mock hiện gửi `POST /orders/sync`, nhưng `FSCM-Backend` hiện chưa có endpoint này; khi tích hợp thật phải đổi từng queue item sang `POST /orders` với `clientOrderKey` ổn định, hoặc thống nhất bổ sung batch-sync endpoint ở backend trước khi release.

## Lưu ý khi nối API thật

- Mock đang đăng nhập bằng số điện thoại + mật khẩu, trong khi backend thật dùng `POST /api/v1/auth/login` với `email/password` và JWT refresh rotation. Khi nối thật phải đổi UI/model đăng nhập sang email hoặc thống nhất bổ sung facade đăng nhập bằng điện thoại; không giả định endpoint mock tồn tại ở backend.
- Model trong `data/models` khớp với mock; đối chiếu lại với Swagger của backend và sửa một phía cho thống nhất.
- Thời gian gửi lên server phải là ISO 8601 có `Z` hoặc offset (Npgsql từ chối DateTime không rõ múi giờ).
- Trước khi bàn giao thay đổi, chạy `dart format`, `flutter analyze` và `flutter test`; không dựa vào việc mock mode chạy được để kết luận contract backend đã khớp.
