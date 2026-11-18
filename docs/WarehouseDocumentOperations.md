# Warehouse Keeper: nhập và xuất bằng app

Thanh điều hướng **Nhập/Xuất** mở bốn nghiệp vụ riêng. Tài khoản chỉ thấy chứng từ ở các kho được phân công. Backend vẫn kiểm tra quyền kho trên mỗi thao tác; app dùng bộ `/warehouse-documents` chung với web.

| Nghiệp vụ | Nguồn việc | Thao tác thủ kho |
|---|---|---|
| Nhập từ nhà máy | Hàng đã được nhà máy phát hành đến kho | Mở PNK gắn pallet → camera quét pallet → server lưu lần quét → kiểm từng CID đạt/thiếu/hỏng → xác nhận nhận → hoàn tất PNK |
| Nhập luân chuyển | PXK luân chuyển đã ghi sổ về kho đích | Mở PNK từ PXK nguồn → camera quét từng CID → xác nhận ghi sổ PNK |
| Xuất bán hàng | Yêu cầu xuất cho đơn hàng đã có PO | Tạo/mở PXK dự thảo → camera quét từng CID → xác nhận ghi sổ cùng PXK |
| Xuất luân chuyển | Yêu cầu luân chuyển do quản trị lập | Kho gửi tạo/mở PXK dự thảo → quét CID → ghi sổ PXK để kho đích nhận hàng |

Nhà máy chỉ định kho đích, app không cho thay kho đó. Lần quét pallet được ghi trên máy chủ kèm người quét và thời gian; không dùng nhập tay thay tín hiệu camera trong các màn chứng từ này. Quét không tự xác nhận nhập tồn: nhà máy chỉ cộng carton đạt sau xác nhận kiểm đếm, luân chuyển chỉ cộng ở kho đích sau ghi sổ PNK. Lập PNK hoặc hoàn tất lại không cộng tồn hai lần.

Phiếu trên app hiển thị số chứng từ, ngày lập, trạng thái, SKU/batch/HSD, carton và tiến độ quét. Nhập nhà máy có lịch sử quét cùng biên bản thiếu/hỏng/cách ly. Bản in/PDF phiếu nhập hiện có trên web dùng chung chứng từ.

Web: **Nhập kho** có Nhập từ nhà máy / Nhập luân chuyển; **Xuất kho** có Xuất bán hàng / Xuất luân chuyển. **Luân chuyển kho** vẫn dùng để lập yêu cầu và theo dõi toàn bộ chuỗi. Phiếu nhập luân chuyển đi về màn Nhập kho; phiếu soạn/xuất đi về màn Xuất kho.

## Triển khai

Backend dùng các API đã triển khai cho chứng từ kho, không cần schema mới. Phải triển khai frontend mới và **build/cài APK mới**; deploy Vercel không cập nhật app đã cài. Chạy `scripts/Build-WarehouseOperations.ps1` trong PowerShell có quyền dùng Flutter/Android SDK để restore, analyze, test và build APK thử nghiệm trỏ API production. Cần thử camera vật lý và luồng hai tài khoản kho gửi/kho nhận trên điện thoại sau khi cài.

## PXK trước khi quét

Chứng từ mới được tạo trực tiếp với Kind=Issue, mã PXK và trạng thái Open, chưa giảm tồn. Quét đủ hàng rồi xác nhận ghi sổ giữ nguyên ID/mã PXK. Backend vẫn hỗ trợ các phiếu soạn Picking cũ chưa hoàn tất.

Trang chủ chỉ dùng chứng từ kho, không hiển thị picking list cũ. Mỗi nghiệp vụ có Cần xử lý / Lịch sử. Yêu cầu đã có PXK không tạo thêm một việc trùng. PXK Posted chỉ xem lại; chỉ khi vào Nhập luân chuyển mới có thao tác mở PNK kho đích. Tab Quét theo phiếu yêu cầu chọn chứng từ trước khi mở camera.
