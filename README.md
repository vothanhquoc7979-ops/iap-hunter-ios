# IAP Hunter iOS (SwiftUI Native)

Ứng dụng iOS Native hỗ trợ:
1. **Tự động quét danh sách các gói In-App Purchase (IAP)** của bất kỳ ứng dụng nào trên App Store (tìm theo tên, dán link App Store, App ID hoặc Bundle ID).
2. **Phát hiện các gói IAP ẩn / A-B Testing cùng tên nhưng chênh lệch giá** (ví dụ: phát hiện gói `Super Duolingo` có các biến thể giá `599.000đ`, `689.000đ`, `860.000đ` để chọn gói rẻ nhất).
3. **So sánh giá IAP đồng thời trên 10 Quốc gia** (`🇻🇳 Việt Nam`, `🇹🇷 Thổ Nhĩ Kỳ`, `🇳🇬 Nigeria`, `🇪🇬 Ai Cập`, `🇮🇳 Ấn Độ`, `🇵🇰 Pakistan`, `🇧🇷 Brazil`, `🇮🇩 Indonesia`, `🇵🇭 Philippines`, `🇺🇸 Mỹ`) và **tự động quy đổi ra VNĐ** theo tỷ giá thực tế.
4. **Điều hướng thanh toán & đổi gói ẩn (Add để thanh toán)**:
   - Mở trực tiếp bảng quản lý thuê bao gốc của iOS qua **StoreKit 2** (`AppStore.showManageSubscriptions`) hoặc Deep Link `itms-apps://apps.apple.com/account/subscriptions` (*See All Plans*) để chọn gói giá rẻ ẩn và xác nhận thanh toán bằng FaceID.
   - Mở trực tiếp trang App Store theo đúng Storefront của quốc gia có gói rẻ nhất.

---

## Cấu trúc dự án

- `IAPHunter/IAPHunterApp.swift`: Điểm khởi chạy ứng dụng SwiftUI.
- `IAPHunter/Models/IAPModels.swift`: Cấu trúc dữ liệu cho App, Gói IAP, Nhóm gói ẩn (A/B Testing), Quốc gia & Tỷ giá.
- `IAPHunter/Services/AppStoreIAPService.swift`: Engine bóc tách dữ liệu IAP từ `serialized-server-data` của Apple App Store, tích hợp bộ chặn redirect `itms-apps://` và quét đa luồng (`TaskGroup`) 10 quốc gia.
- `IAPHunter/Services/CurrencyService.swift`: Tự động cập nhật tỷ giá ngoại tệ theo thời gian thực và quy đổi chính xác định dạng tiền tệ của từng vùng sang VNĐ.
- `IAPHunter/Views/`: Giao diện Tìm kiếm (`SearchView`), Phân tích gói ẩn & So sánh 10 quốc gia (`AppIAPDetailView`), Thanh toán gói ẩn (`PurchaseActionSheet`), và Lưu trữ & Tỷ giá (`SavedAppsView`).
- `project.yml` & `.github/workflows/build-ipa.yml`: Cấu hình tự động xuất file `IAPHunter-Unsigned.ipa` trên GitHub Actions.

---

## Hướng dẫn xuất file `.ipa` trên Windows (qua GitHub Actions)

Vì bạn đang dùng Windows, dự án đã được cấu hình sẵn **GitHub Actions** để máy chủ macOS của GitHub tự động biên dịch ra file `.ipa`:

1. Tạo một Repository mới trên GitHub (có thể để **Private** cho riêng bạn dùng).
2. Mở Terminal / PowerShell tại thư mục `c:\Users\PC\Downloads\hihi` và chạy các lệnh sau để đẩy code lên:
   ```powershell
   git init
   git add .
   git commit -m "Initial commit: IAP Hunter iOS App"
   git branch -M main
   git remote add origin https://github.com/<TEN_USER_CUA_BAN>/<TEN_REPO>.git
   git push -u origin main
   ```
3. Truy cập tab **Actions** trên trang GitHub Repository của bạn:
   - Workflow **Build iOS IPA (Sideloadly / TrollStore)** sẽ tự động chạy (mất khoảng 1–2 phút).
   - Sau khi chạy xong (dấu tích xanh), kéo xuống mục **Artifacts** và tải file **`IAPHunter-IPA.zip`** về máy, giải nén ra sẽ được file **`IAPHunter-Unsigned.ipa`**.

---

## Cách cài đặt vào iPhone

- **Nếu dùng TrollStore:** Gửi file `IAPHunter-Unsigned.ipa` qua AirDrop / iCloud Drive / Telegram vào iPhone $\rightarrow$ Mở bằng **TrollStore** và bấm **Install** (vĩnh viễn không hết hạn).
- **Nếu dùng Sideloadly (trên Windows):**
  1. Cắm cáp iPhone vào máy tính Windows, mở **Sideloadly**.
  2. Kéo file `IAPHunter-Unsigned.ipa` vào Sideloadly, nhập Apple ID của bạn và bấm **Start** (Sideloadly sẽ tự động ký chứng chỉ 7 ngày/1 năm và cài đặt vào iPhone).
