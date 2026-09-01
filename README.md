# Chi Tiêu — iOS 15+

App quản lý chi tiêu cá nhân native SwiftUI, giao diện dark green, tối ưu cho thao tác nhập nhanh.

## V1 có sẵn

- Nhập số tiền, nội dung, danh mục và ngày giờ.
- Mở màn hình thêm khoản chi là tự focus vào ô tiền và bật bàn phím số.
- Tổng chi tiêu hôm nay và tháng hiện tại.
- Lịch sử từng khoản, nhóm theo ngày.
- Tìm kiếm theo tên món hoặc danh mục.
- Chạm vào một khoản để sửa hoặc xóa.
- Thống kê tháng hiện tại theo danh mục.
- Xuất toàn bộ dữ liệu ra CSV để mở bằng Numbers/Excel.
- Dữ liệu lưu local trong `expenses.json` ở Documents của app.
- Không tài khoản, không API, không server.
- Deployment target: iOS 15.0.
- Bundle ID: `com.local.chitieu`.

## Cách 1 — Build IPA trên Mac

Mở Terminal tại thư mục project rồi chạy:

```bash
./build_ipa_mac.sh
```

Sau khi xong sẽ có `ChiTieu.ipa` ngay trong thư mục project.

## Cách 2 — Không có Mac: GitHub Actions

Project đã có sẵn `.github/workflows/build-ipa.yml`.

1. Tạo một repository GitHub.
2. Upload toàn bộ nội dung trong thư mục project lên repository.
3. Vào tab **Actions** > **Build ChiTieu IPA**.
4. Chọn **Run workflow**.
5. Khi build xong, tải artifact **ChiTieu-IPA**.
6. Giải nén artifact để lấy `ChiTieu.ipa`.
7. Chuyển IPA sang iPhone và cài bằng TrollStore.

## Xcode project

Nếu muốn chỉnh sửa giao diện/chức năng, mở `ChiTieu.xcodeproj` bằng Xcode.
