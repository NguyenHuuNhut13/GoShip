# Tài liệu Đặc tả Yêu cầu Phần mềm (SRS)
## Hệ thống Quản lý & Điều phối Giao vận GoShip Logistics

> **Phiên bản:** 2.0 (Cập nhật Kiến trúc Toàn diện theo Dự Án Thực Tế)  
> **Nền tảng phát triển:** Flutter Mobile (Android/iOS) • Web Admin Portal (React 18 + Vite + TypeScript + Tailwind)  
> **Dịch vụ đám mây & AI:** Firebase Cloud Firestore • Google Gemini AI • Agora RTC VoIP • OSRM OpenStreetMap  

---

## 1. Giới thiệu (Introduction)

### 1.1 Mục đích
Tài liệu Đặc tả Yêu cầu Phần mềm (SRS) này cung cấp các mô tả toàn diện về yêu cầu chức năng, yêu cầu phi chức năng, thiết kế cơ sở dữ liệu và kiến trúc triển khai cho hệ sinh thái **GoShip Logistics**. Mục tiêu của dự án là xây dựng nền tảng công nghệ giao vận chặng cuối (Last-Mile Logistics) số hóa 100% quy trình, tối ưu hóa quá trình điều phối phương tiện, trợ lực bốc xếp thông minh bằng Trí tuệ nhân tạo (**Google Gemini AI Cargo Advisor**), tích hợp viễn thông thoại trực tiếp trong ứng dụng (**Agora RTC VoIP Engine**) và giám sát dòng tiền minh bạch theo thời gian thực trên **Cloud Firestore**.

### 1.2 Phạm vi hệ thống
Hệ thống GoShip Logistics bao gồm 3 phân hệ cấu thành đồng bộ:
1. **Ứng dụng Di động Khách hàng (GoShip Customer Mobile App):**
   - Đặt xe nhanh chóng qua quy trình 3 bước (Booking Funnel).
   - Hỗ trợ lộ trình đa điểm dừng (**Multi-stop dropoff từ 2 đến 4 điểm giao**).
   - Kéo ghim bản đồ toàn màn hình (`FullscreenMapPicker`) tự động dịch ngược tọa độ sang địa chỉ tiếng Việt.
   - **Google Gemini AI Cargo Advisor:** Tự động tính toán thể tích ($m^3$) từ kích thước Dài x Rộng x Cao và khối lượng, đưa ra khuyến nghị dòng xe tối ưu, tránh tình trạng đặt sai xe.
   - Theo dõi trực tiếp (Live Tracking) vị trí xe tài xế 60 FPS trên nền bản đồ OSRM.
   - Đàm thoại nội bộ 2 chiều qua **Agora RTC VoIP** và Chat trực tiếp trong chuyến đi.
   - Áp dụng mã giảm giá động từ Firestore (`vouchers`) và chọn cổng thanh toán COD / QR MoMo / QR ZaloPay.
   - Quản lý biên bản giao hàng điện tử (**e-POD**) và đánh giá tài xế 2 chiều.
2. **Ứng dụng Di động Đối tác Tài xế (GoShip Driver Mobile App):**
   - Radar quét cuốc xe thời gian thực theo bán kính tùy biến (≤5km, ≤10km, ≤20km, Tất cả).
   - **Cơ chế Ký quỹ bảo đảm (Escrow Balance 15%):** Tự động kiểm tra và chặn nhận cuốc nếu số dư ký quỹ không đủ 15% hoa hồng chuyến xe.
   - Màn hình Dẫn đường chuyên nghiệp Turn-by-Turn OSRM kiểu Google Maps với thuật toán **Tự động tìm lại đường (Rerouting)** khi đi chệch tuyến >50m.
   - Quy trình bàn giao điện tử **e-POD**: Chụp ảnh bốc hàng tại điểm lấy + Ký nhận trực tiếp trên màn hình cảm ứng (**Touchscreen Signature**) tại điểm giao kèm chụp ảnh hàng hóa thực tế.
   - **Kế toán Dòng tiền Ví Thu Nhập & Ký Quỹ:** Tách bạch Ví thu nhập (hưởng 85% cước gốc) và Ví ký quỹ (khấu trừ 15% hoa hồng). Sổ cái giao dịch minh bạch.
3. **Cổng Quản trị & Điều phối Vận hành (Web Admin Portal & Mobile Admin):**
   - **Web Admin Portal (React 18 + Vite + TypeScript + Tailwind + Leaflet + Recharts):** Giám sát bản đồ Live Fleet toàn thành phố, quản trị vòng đời đơn hàng, duyệt hồ sơ định danh đối tác tài xế (KYC CCCD 2 mặt & Giấy phép lái xe), cấu hình bảng giá động thời gian thực (`PricingConfigService`), quản lý mã khuyến mại Voucher và tiếp nhận xử lý sự cố (Incidents).
   - **Mobile Admin tích hợp trên Flutter App (`AdminDashboardScreen`):** Giám sát đội xe trực tiếp, điều chỉnh bảng giá tức thời và duyệt tài xế ngay trên thiết bị di động.

### 1.3 Đối tượng hướng đến
- **Đội ngũ Kỹ sư Phát triển (Developers):** Nắm vững kiến trúc đa phân hệ, luồng dữ liệu thời gian thực Firestore, API tích hợp Agora RTC, OSRM và Gemini AI.
- **Đội ngũ Điều phối viên & Vận hành (Dispatchers & Ops):** Sử dụng các công cụ Dashboard KPI, Bản đồ đội xe Leaflet để theo dõi hiệu suất, xử lý khiếu nại và duyệt hồ sơ đối tác.
- **Khách hàng & Doanh nghiệp gửi hàng (Customers):** Trải nghiệm dịch vụ giao hàng thông minh, minh bạch giá cước và an tâm về an toàn hàng hóa qua biên bản e-POD.
- **Đối tác Tài xế vận tải (Driver Partners):** Công cụ nhận cuốc công bằng, tối ưu lộ trình di chuyển, nhận cuốc bảo đảm và quyết toán thu nhập 85% ngay tức thì.
- **Hội đồng Giảng viên & Chuyên gia Phản biện:** Đánh giá tính khả thi, mức độ hoàn thiện kỹ thuật và giá trị thực tiễn của sản phẩm trong kỳ bảo vệ Đồ án Tốt nghiệp.

---

## 2. Mô tả tổng quan (Overall Description)

### 2.1 Bối cảnh sản phẩm
Tại các đô thị lớn tại Việt Nam, nhu cầu vận chuyển hàng hóa cồng kềnh, thiết bị gia dụng, vật liệu và bưu kiện thương mại điện tử tăng trưởng vượt bậc. Tuy nhiên, các giải pháp truyền thống bộc lộ nhiều điểm nghẽn: khách hàng không ước lượng được kích thước dẫn đến đặt sai loại xe, tài xế đến nơi phải từ chối cuốc gây lãng phí thời gian; thiếu bằng chứng bàn giao hàng hóa khiến tranh chấp hư hỏng xảy ra thường xuyên; việc đối soát dòng tiền và phí sàn thủ công gây chậm trễ thu nhập cho đối tác lái xe. 

GoShip Logistics ra đời để giải quyết triệt để các bài toán trên thông qua việc số hóa toàn diện quy trình giao nhận bằng Điện toán đám mây và Trí tuệ nhân tạo.

### 2.2 Kiến trúc tổng quan
Hệ thống được thiết kế theo mô hình phân tầng chuẩn mực (Clean Architecture & Cloud-Native):
- **Tầng Giao diện Người dùng (Client Layer):** Ứng dụng di động Flutter đa nền tảng (Customer & Driver) kết hợp Cổng quản trị Web Admin Portal (React 18, Vite, TypeScript, Tailwind).
- **Tầng Trí tuệ Nhân tạo (AI Service Layer):** Google Gemini 1.5 Pro/Flash API chịu trách nhiệm tính toán thể tích và tư vấn loại xe (Cargo Advisor) cùng Trợ lý Chatbot hỗ trợ logistics.
- **Tầng Viễn thông & Đàm thoại (Telephony Layer):** Agora RTC Voice Engine cung cấp hạ tầng đàm thoại VoIP 2 chiều nội bộ theo thời gian thực (độ trễ <200ms).
- **Tầng Bản đồ & Định tuyến (GIS & Routing Layer):** OpenStreetMap & OSRM Engine đảm nhiệm vẽ tuyến đường, tính khoảng cách, thời gian di chuyển và dịch ngược địa chỉ tiếng Việt (Nominatim).
- **Tầng Dữ liệu Đám mây (Cloud Data Layer):** Firebase Cloud Firestore (Đồng bộ Real-time 2 chiều), Firebase Cloud Storage (Lưu trữ ảnh e-POD, CCCD), Cơ chế xác thực bảo mật Hybrid SHA-256 + Salt bí mật (`goship_sec_salt_2026`).

### 2.3 Các nhóm người dùng

| Nhóm người dùng | Quyền hạn | Trách nhiệm & Hành vi chính trong hệ thống |
| :--- | :--- | :--- |
| **Khách hàng (Customer)** | Truy cập Customer App | Tạo đơn hàng 1 đến 4 điểm giao; nhờ AI tư vấn xe; theo dõi live GPS xe 60 FPS; gọi VoIP; thanh toán COD/Ví; ký nhận e-POD; đánh giá tài xế. |
| **Đối tác Tài xế (Driver)** | Truy cập Driver App | Nộp hồ sơ KYC (CCCD, GPLX, biển số); nạp quỹ ký quỹ (duy trì >15%); bật Online quét đơn; nhận cuốc; dẫn đường Turn-by-Turn OSRM; bốc hàng & ký e-POD; nhận 85% cước vào ví thu nhập. |
| **Quản trị viên (Admin)** | Truy cập Web & Mobile Admin | Giám sát bản đồ Live Fleet toàn thành phố; duyệt hồ sơ KYC đối tác; điều chỉnh Bảng giá động thời gian thực (PricingConfigService); quản lý mã Voucher; xử lý khiếu nại (Incidents). |
| **Đội ngũ Kỹ sư (Dev/Ops)** | Toàn quyền hệ thống | Duy trì hoạt động Cloud Firestore, giám sát quota API Gemini & Agora, bảo trì mã nguồn Flutter & React, đảm bảo `flutter analyze` đạt 0 lỗi. |

---

## 3. Các Module chức năng chi tiết (Functional Modules)

### 3.1 Module Ứng dụng Khách hàng (GoShip Customer App)
- **Quy trình Tạo đơn 3 bước (Booking Flow):**
  - **Bước 1 - Lộ trình & Bản đồ (Step 1):** Khách hàng nhập địa chỉ lấy hàng và hỗ trợ thêm tối đa 4 điểm giao hàng (Multi-dropoff). Tích hợp công cụ kéo ghim bản đồ toàn màn hình (`FullscreenMapPicker`) tự động dịch ngược tọa độ sang địa chỉ tiếng Việt; hỗ trợ đổi chiều lấy - giao và chọn nhanh từ Sổ địa chỉ đã lưu (Nhà riêng, Kho, Công ty).
  - **Bước 2 - Kiện hàng & Trợ lý AI (Step 2):** Cho phép lựa chọn giữa 4 dòng phương tiện (Xe Bán tải, Xe Van, Xe Tải, Container). Khách hàng nhập kích thước kiện hàng (Dài x Rộng x Cao) và trọng lượng. Nút bấm *"Nhờ AI Tư Vấn"* kích hoạt Google Gemini AI Cargo Advisor để phân tích thể tích $m^3$ và khuyến nghị loại xe chính xác nhất. Hỗ trợ chụp ảnh kiện hàng trực tiếp và kịch bản điền nhanh người gửi/người nhận.
  - **Bước 3 - Tính cước & Thanh toán (Step 3):** Cước phí được tính toán tự động dựa trên bảng giá động Cloud Firestore (`PricingConfigService`). Hỗ trợ nhập hoặc chọn mã giảm giá từ danh sách Voucher Cloud (`WELCOME30`, `GOSHIP50`, `TRUCK50`, `GOSHIP15`). Lựa chọn phương thức thanh toán: Tiền mặt khi nhận hàng (COD), QR Ví MoMo hoặc QR ZaloPay. Tích hợp cơ chế khóa nút chống nhấp đúp (Double-tap prevention) khi gửi request tạo đơn lên Cloud.
- **Theo dõi Trực tiếp & Giám sát Chuyến đi (Live Tracking Screen):**
  - Bản đồ theo dõi hành trình xe di chuyển với thuật toán nội suy mượt mà 60 FPS.
  - Hiển thị HUD thông tin đối tác tài xế (Ảnh đại diện, Họ tên, SĐT, Biển số xe, Loại xe, Điểm đánh giá sao).
  - Tích hợp nút Gọi thoại Agora VoIP đàm thoại nội bộ chất lượng cao và khung Chat trực tiếp lưu lịch sử trên Firestore.
  - Khách hàng có quyền Hủy đơn hàng kèm chọn lý do rõ ràng khi tài xế chưa bốc hàng.
  - Sau khi hoàn tất chuyến, Trang chủ hiển thị Banner màu xanh ngọc bích (Emerald) nhắc nhở khách hàng xem lại ảnh chứng từ e-POD và đánh giá 5 sao tài xế.

### 3.2 Module Ứng dụng Đối tác Tài xế (GoShip Driver App)
- **Radar Quét đơn & Kiểm soát Ký quỹ:**
  - Hiển thị bản đồ vị trí thực tế của tài xế kèm nút gạt Trực tuyến / Ngoại tuyến (Online/Offline).
  - Hệ thống tự động quét và phân bổ đơn hàng mới theo bán kính tùy chọn (≤5km, ≤10km, ≤20km hoặc Tất cả).
  - **Cơ chế Ký quỹ bảo đảm (Escrow 15%):** Nếu số dư ký quỹ không đủ 15% hoa hồng cước gốc của chuyến xe, hệ thống sẽ cảnh báo và chặn nhận cuốc.
- **Dẫn đường Thời gian thực chuẩn Google Maps (HUD Navigation):**
  - Khi tài xế bấm *"Bắt đầu di chuyển"*, màn hình chuyển sang chế độ HUD dẫn đường Turn-by-Turn chuẩn Google Maps.
  - Hiển thị ngã rẽ tiếp theo (Rẽ trái, Rẽ phải, Đi thẳng), tên đường, khoảng cách còn lại và vận tốc di chuyển.
  - Đặc biệt, tích hợp thuật toán **Tự động tìm lại đường (Rerouting):** Khi tài xế di chuyển lệch khỏi tuyến đường ban đầu quá 50 mét, hệ thống tự động gọi OSRM vẽ lại lộ trình mới tối ưu.
- **Quy trình Giao nhận Đa điểm & Bằng chứng điện tử (e-POD):**
  - Quy trình giao nhận qua 2 bước nghiêm ngặt: (1) Chụp ảnh xác nhận bốc hàng tại điểm lấy hàng; (2) Tại điểm giao hàng, tài xế chụp ảnh hàng hóa bàn giao thành công và đưa màn hình cho người nhận ký tên trực tiếp bằng cảm ứng (**Touchscreen Signature**).
  - Biên bản e-POD hoàn tất sẽ được đóng dấu Watermark (tọa độ GPS, mốc thời gian) và lưu trữ vĩnh viễn trên Cloud.
- **Kế toán Dòng tiền Ví Thu Nhập & Ký Quỹ (85/15 Split):**
  - Tách biệt 100% giữa Ví Thu nhập (tài chính) và Tài khoản (hồ sơ, cài đặt).
  - Ngay khi đơn hàng hoàn tất, hệ thống tự động cộng **85% cước gốc** vào Ví thu nhập và khấu trừ **15% hoa hồng** vào Ví ký quỹ.
  - Tài xế có thể nạp/rút tiền linh hoạt với tài khoản ngân hàng liên kết.

### 3.3 Module Trí tuệ Nhân tạo & Viễn thông Thực địa (AI & Telephony)
- **Google Gemini AI Cargo Advisor:** Sử dụng Google Gemini 1.5 API phân tích tự động thông số kích thước Dài x Rộng x Cao (cm/m) và Khối lượng (kg). Hệ thống tính toán thể tích thực tế ($m^3$), so sánh với quy cách thùng xe tiêu chuẩn của 4 dòng phương tiện (Bán tải: 500kg - $1.5m^3$; Van: 1,000kg - $3.5m^3$; Xe tải: 2,500kg - $10m^3$; Container: 15,000kg - $45m^3$) để đưa ra khuyến nghị lựa chọn xe chuẩn xác kèm cảnh báo quá tải, quá khổ.
- **Trợ lý Chatbot Hỗ trợ Logistics AI:** Tích hợp cửa sổ chat thông minh ngay trên Trang chủ khách hàng, giải đáp 24/7 mọi thắc mắc về chính sách vận chuyển, quy cách đóng gói hàng cồng kềnh, cách tính phí đường dài và hỗ trợ xử lý sự cố.
- **Viễn thông Đàm thoại VoIP Nội bộ (Agora RTC Engine):** Tích hợp Agora RTC Engine SDK với cơ chế sinh Token bảo mật (`AgoraTokenBuilder`). Cung cấp tính năng gọi điện thoại thoại IP trực tiếp 2 chiều giữa Khách hàng và Tài xế với độ trễ <200ms, hoạt động ổn định trên cả mạng 4G/WiFi mà không làm phát sinh cước viễn thông thông thường.

### 3.4 Module Quản trị Trung tâm (Web & Mobile Admin Portal)
- **Báo cáo Tổng quan KPI & Doanh thu:** Trực quan hóa số lượng đơn hàng, doanh thu thực tế, biểu đồ tăng trưởng doanh số theo tuần/tháng bằng thư viện Recharts.
- **Bản đồ Giám sát Đội xe Trực tuyến (Live Fleet Map):** Tích hợp bản đồ số Leaflet hiển thị trực quan toàn bộ các phương tiện đang hoạt động trên địa bàn, sử dụng kỹ thuật gom cụm (Marker Clustering) tối ưu hiệu năng hiển thị hàng trăm xe.
- **Quản lý Vòng đời Đơn hàng & e-POD:** Bộ lọc đa tiêu chí theo trạng thái (Pending, Delivering, Completed, Cancelled); cho phép quản trị viên xem lại chi tiết lộ trình, ảnh chụp kiện hàng, chữ ký số và biên bản e-POD đối soát.
- **Quản lý & Phê duyệt KYC Đối tác Tài xế:** Duyệt hồ sơ định danh tài xế mới (kiểm tra ảnh chụp CCCD 2 mặt, Giấy phép lái xe, ảnh xe, biển số) với hai thao tác Chấp thuận (Approve) hoặc Từ chối (Reject); hỗ trợ khóa tài khoản vi phạm.
- **Cấu hình Bảng giá Động (Dynamic Pricing Engine):** Cho phép Quản trị viên điều chỉnh cước mở cửa, đơn giá mỗi km tiếp theo, phụ phí giờ cao điểm và cước chờ cho từng loại xe. Thay đổi này được cập nhật tức thời (Real-time sync) tới tất cả ứng dụng di động khách hàng đang mở thông qua `PricingConfigService`.
- **Quản lý Khuyến mãi (Voucher Management):** Tạo mới và quản lý các mã khuyến mãi (`WELCOME30`, `GOSHIP50`, `TRUCK50`...), cấu hình giá trị giảm (theo % hoặc số tiền cố định), mức giảm tối đa, ngày hết hạn và số lượt sử dụng khả dụng.
- **Quản lý Khiếu nại & Sự cố (Incidents):** Tiếp nhận và điều phối giải quyết các khiếu nại, sự cố hư hỏng hoặc trễ hạn trong quá trình vận chuyển.

---

## 4. Thiết kế Cơ sở dữ liệu (Database Design)

### 4.1 Kiến trúc dữ liệu NoSQL Cloud Firestore
Hệ thống GoShip Logistics sử dụng kiến trúc Cơ sở dữ liệu NoSQL đám mây trên nền tảng **Firebase Cloud Firestore**. Mô hình NoSQL thời gian thực này mang lại khả năng mở rộng linh hoạt, độ trễ cập nhật <100ms và hỗ trợ cơ chế lắng nghe sự kiện (Live Snapshot Listeners) phù hợp hoàn hảo cho bài toán điều phối xe và định vị GPS di động.

### 4.2 Đặc tả Chi tiết các Collections

#### 1. Collection `users` (Tài khoản người dùng & Định danh)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `id / docId` | String | PK | Mã định danh duy nhất (`usr_0917795211` hoặc `usr_admin`) |
| `role` | String | Not Null | Phân quyền: `customer`, `driver`, `admin` |
| `name` | String | Not Null | Họ và tên hiển thị của người dùng |
| `phone` | String | Unique | Số điện thoại đăng nhập và liên lạc |
| `email` | String | Nullable | Địa chỉ email liên hệ |
| `email_lower` | String | Indexed | Email chuẩn hóa chữ thường phục vụ tra cứu nhanh |
| `password_hash` | String | Not Null | Mật khẩu đã băm SHA-256 kèm Salt bảo mật bí mật |
| `account_status` | String | Default 'active' | Trạng thái: `active`, `pending`, `locked` |
| `avatar_url` | String | Nullable | Đường dẫn ảnh đại diện cá nhân lưu trên Cloud |
| `rating` | Float | Check (1.0..5.0) | Điểm đánh giá uy tín trung bình (VD: 4.9 sao) |
| `total_orders` | Integer | Default 0 | Tổng số cuốc xe đã thực hiện thành công |
| `plate_number` | String | Nullable | Biển số xe đăng ký (dành riêng cho vai trò tài xế) |
| `vehicle_type` | String | Nullable | Loại xe đăng ký: `motorbike`, `van`, `truck`, `container` |
| `cccd_front_url`| String | Nullable | Ảnh chụp mặt trước CCCD duyệt KYC tài xế |
| `cccd_back_url` | String | Nullable | Ảnh chụp mặt sau CCCD duyệt KYC tài xế |
| `license_url` | String | Nullable | Ảnh chụp Giấy phép lái xe đối tác |
| `created_at` | Timestamp | Default NOW() | Thời điểm đăng ký tài khoản |

#### 2. Collection `orders` (Đơn hàng giao nhận & Hành trình)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `order_code` | String | PK | Mã vận đơn duy nhất (VD: `ORD1793098`, `GS89214`) |
| `status` | String | Not Null | `pending`, `pendingDirect`, `accepted`, `delivering`, `completed`, `cancelled` |
| `customer_phone`| String | Indexed | Số điện thoại khách đặt đơn |
| `sender_name` | String | Not Null | Họ tên người gửi hàng tại điểm lấy |
| `sender_phone` | String | Not Null | Số điện thoại liên lạc người gửi |
| `pickup_address`| String | Not Null | Địa chỉ văn bản điểm lấy hàng |
| `pickup_lat` | Float | Not Null | Vĩ độ GPS điểm lấy hàng |
| `pickup_lng` | Float | Not Null | Kinh độ GPS điểm lấy hàng |
| `dropoff_addresses`| Array<String> | Not Null | Mảng danh sách các điểm giao hàng (1 đến 4 điểm) |
| `dropoff_recipients`| Array<Map> | Not Null | Mảng chi tiết người nhận: tên, SĐT, quy cách kiện hàng từng điểm |
| `dropoff_lats` | Array<Float> | Not Null | Mảng vĩ độ GPS các điểm giao |
| `dropoff_lngs` | Array<Float> | Not Null | Mảng kinh độ GPS các điểm giao |
| `distance_km` | Float | Not Null | Tổng chiều dài quãng đường tính theo thuật toán OSRM |
| `duration_minutes`| Integer | Not Null | Thời gian di chuyển ước tính (ETA) |
| `vehicle_type` | String | Not Null | Loại xe yêu cầu: `motorbike`, `van`, `truck`, `container` |
| `vehicle_name` | String | Not Null | Tên hiển thị phương tiện (Xe Bán tải, Xe van...) |
| `total_fee` | Integer | Not Null | Cước phí thực tế khách hàng phải thanh toán |
| `original_fee` | Integer | Not Null | Cước gốc trước khi áp dụng mã giảm giá Voucher |
| `discount_amount`| Integer | Default 0 | Số tiền được giảm trừ từ Voucher sàn tài trợ |
| `promo_code` | String | Nullable | Mã Voucher đã áp dụng (`WELCOME30`, `GOSHIP50`...) |
| `payment_method`| String | Not Null | Phương thức thanh toán: `cash` (COD), `momo`, `zalopay` |
| `is_payment_received`| Boolean | Default false | Trạng thái thanh toán tiền cước |
| `driver_id` | String | Nullable | Mã định danh đối tác tài xế nhận cuốc |
| `driver_name` | String | Nullable | Họ tên tài xế phục vụ cuốc xe |
| `driver_phone` | String | Nullable | Số điện thoại tài xế |
| `driver_plate` | String | Nullable | Biển số xe của tài xế nhận cuốc |
| `package_category`| String | Not Null | Ngành hàng: Hàng tiêu chuẩn, Đồ điện tử, Hàng dễ vỡ... |
| `weight_category`| String | Not Null | Phân loại khối lượng: Dưới 50kg, 50-200kg, 200-500kg... |
| `dimensions` | String | Nullable | Kích thước Dài x Rộng x Cao của kiện hàng |
| `package_photos`| Array<String>| Default [] | Mảng link ảnh chụp kiện hàng lúc đặt xe |
| `epod_photos` | Array<String>| Default [] | Mảng link ảnh chứng từ e-POD khi giao hàng thành công |
| `cancel_reason` | String | Nullable | Lý do hủy đơn hàng nếu có sự cố |
| `created_at` | Timestamp | Default NOW() | Thời điểm khởi tạo đơn hàng trên Cloud |
| `completed_at` | Timestamp | Nullable | Thời điểm đơn hàng hoàn tất bàn giao |

#### 3. Collection `online_drivers` (Giám sát vị trí đội xe Live Fleet)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `driver_id / docId`| String | PK | Mã tài xế (trùng khớp ID tài khoản) |
| `name` | String | Not Null | Họ và tên đối tác lái xe |
| `phone` | String | Not Null | Số điện thoại liên lạc |
| `plate` | String | Not Null | Biển số phương tiện |
| `vehicle_type` | String | Not Null | Loại xe: `motorbike`, `van`, `truck`, `container` |
| `lat` | Float | Not Null | Vĩ độ GPS hiện tại |
| `lng` | Float | Not Null | Kinh độ GPS hiện tại |
| `heading` | Float | Default 0.0 | Góc hướng đầu xe di chuyển (0 - 360 độ) |
| `speed` | Float | Default 0.0 | Vận tốc di chuyển tức thời (km/h) |
| `is_online` | Boolean | Not Null | Trạng thái sẵn sàng nhận đơn hàng |
| `is_busy` | Boolean | Default false | Trạng thái đang trong cuốc xe vận chuyển |
| `updated_at` | Timestamp | Default NOW() | Mốc thời gian phát GPS gần nhất |

#### 4. Collection `driver_wallets` (Ví Thu Nhập, Ký Quỹ & Sổ Cái 85/15)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `driver_id / docId`| String | PK | Mã đối tác tài xế sở hữu ví |
| `driver_name` | String | Not Null | Họ tên đối tác tài xế |
| `driver_phone` | String | Not Null | Số điện thoại đối tác tài xế |
| `wallet_balance`| Integer | Default 0 | Số dư Ví Thu Nhập (hưởng 85% cước gốc cuốc xe) |
| `deposit_balance`| Integer | Default 0 | Số dư Ví Ký Quỹ (duy trì tối thiểu 15% để nhận cuốc) |
| `bank_name` | String | Nullable | Ngân hàng liên kết (VD: MB Bank, Vietcombank) |
| `bank_account_number`| String | Nullable | Số tài khoản ngân hàng liên kết rút tiền |
| `bank_account_owner` | String | Nullable | Tên chủ tài khoản ngân hàng thụ hưởng |
| `transactions` | Array<Map> | Default [] | Sổ cái mảng lịch sử giao dịch: biến động số dư, thời gian, loại (+85%, -15%, nạp, rút) |
| `updated_at` | Timestamp | Default NOW() | Thời điểm cập nhật biến động số dư gần nhất |

#### 5. Collection `pricing_config` (Bảng giá cước động thời gian thực)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `config_id / docId`| String | PK | Định danh cấu hình bảng giá (mặc định: `'default'`) |
| `motorbike` | Map | Not Null | Bảng giá Xe Bán tải: base (35k), perKm (6k), peak (1.2), min (35k), wait (2k) |
| `van` | Map | Not Null | Bảng giá Xe Van: base (50k), perKm (10k), peak (1.2), min (50k), wait (3k) |
| `truck` | Map | Not Null | Bảng giá Xe Tải: base (120k), perKm (15k), peak (1.3), min (120k), wait (5k) |
| `container` | Map | Not Null | Bảng giá Container: base (350k), perKm (25k), peak (1.3), min (350k), wait (10k) |
| `updated_at` | Timestamp | Default NOW() | Mốc thời gian Quản trị viên cập nhật giá cước mới |

#### 6. Collection `vouchers` (Mã khuyến mại & Khấu trừ cước)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `code / docId` | String | PK | Mã khuyến mại (`WELCOME30`, `GOSHIP50`, `TRUCK50`...) |
| `title` | String | Not Null | Tiêu đề mã giảm giá hiển thị trên giao diện |
| `discount_type` | String | Not Null | Loại giảm giá: `'percent'` (%) hoặc `'fixed'` (VNĐ) |
| `discount_value`| Float | Not Null | Giá trị giảm (VD: 30 cho 30%, hoặc 50000 cho 50k) |
| `min_order_value`| Integer | Default 0 | Giá trị đơn hàng tối thiểu để được áp dụng |
| `max_discount` | Integer | Nullable | Mức giảm tối đa (đối với voucher theo %) |
| `is_active` | Boolean | Default true | Trạng thái kích hoạt khả dụng của mã |
| `expire_at` | Timestamp | Nullable | Hạn chót áp dụng mã khuyến mãi |

#### 7. Collection `incidents` (Khiếu nại & Xử lý sự cố)
| Trường (Field) | Kiểu dữ liệu | Ràng buộc | Diễn giải nghiệp vụ GoShip |
| :--- | :--- | :--- | :--- |
| `incident_id` | String | PK | Mã khiếu nại sự cố (VD: `INC_20261028_01`) |
| `order_code` | String | Indexed | Mã vận đơn xảy ra sự cố cần đối soát |
| `reporter_phone`| String | Not Null | Số điện thoại người gửi báo cáo sự cố |
| `type` | String | Not Null | Phân loại sự cố: Hư hỏng hàng, Trễ hẹn, Thái độ tài xế, Thất lạc |
| `description` | String | Not Null | Nội dung mô tả chi tiết diễn biến sự cố |
| `photos` | Array<String>| Default [] | Hình ảnh bằng chứng đính kèm khiếu nại |
| `status` | String | Default 'pending' | Trạng thái giải quyết: `pending`, `investigating`, `resolved` |
| `created_at` | Timestamp | Default NOW() | Thời điểm tiếp nhận sự cố lên hệ thống |

---

## 5. Yêu cầu giao diện (Interface Requirements)

### 5.1 Ngôn ngữ thiết kế và Tiêu chuẩn (Design System)
- **Ứng dụng Di động (Flutter Mobile):** Áp dụng ngôn ngữ Material Design 3 kết hợp các thành phần tương tác mượt mà. Giao diện của Tài xế được thiết kế chuyên biệt cho thao tác một tay (**One-handed Operation**), các nút bấm xác nhận cuốc, bốc hàng và hoàn thành đơn to bản, đặt tại nửa dưới màn hình để tài xế thao tác dễ dàng, an toàn khi đang lưu thông.
- **Cổng Quản trị Điều hành (Web Admin Portal):** Phong cách thiết kế công thái học hiện đại (Modern Clean Flat UI), kết hợp Tailwind CSS, Radix UI và biểu đồ Recharts. Bố cục chia tầng dạng Lưới (Grid) và thanh điều hướng bên (Sidebar Navigation) giúp bao quát toàn bộ hoạt động giám sát xe và dữ liệu điều hành.

### 5.2 Hệ thống Màu sắc chủ đạo (Color Palette)

| Loại màu sắc | Mã Hex | Tên màu | Ý nghĩa & Vị trí ứng dụng trong GoShip |
| :--- | :---: | :--- | :--- |
| **Chủ đạo (Primary Blue)** | `#2563EB` | Xanh Hoàng Gia | Thanh AppBar, Nút bấm chính Đặt xe, Nút Bắt đầu di chuyển, Định danh thương hiệu GoShip |
| **Nhấn mạnh (Accent Orange)** | `#FF6B00` | Cam Đậm | Điểm đến giao hàng, Marker điểm Dropoff, Nút nổi hành động, Huy hiệu cuốc xe mới |
| **Thành công (Emerald Green)**| `#10B981` | Xanh Ngọc Bích | Banner Giao thành công, Biên bản e-POD, Đã thanh toán, Nút Trực tuyến Online |
| **Cảnh báo / Lỗi (Danger Red)**| `#EF4444` | Đỏ Cảnh Báo | Nút Hủy đơn hàng, Báo cáo sự cố, Chặn nhận đơn do thiếu ký quỹ, Đăng xuất |
| **Chờ xử lý (Warning Amber)** | `#F59E0B` | Vàng Cam | Trạng thái đang tìm tài xế, Thông báo nạp tiền ký quỹ, Cảnh báo thời tiết xấu |
| **Nền chính (Background)** | `#F8FAFC` | Xám Nhạt Siêu Sạch | Màu nền ứng dụng, thẻ card đơn hàng, phân cách danh sách |

### 5.3 Danh mục màn hình chi tiết (Screen Inventory - 35+ Screens)

#### 5.3.1 Phân hệ Ứng dụng Khách hàng (Customer App)
1. **Splash Screen:** Màn hình khởi động với hiệu ứng chuyển động logo GoShip cao cấp và tự động chuyển hướng theo trạng thái đăng nhập.
2. **Unified Auth Screen:** Đăng nhập và Đăng ký hợp nhất bằng Email/Số điện thoại với mật khẩu băm bảo mật SHA-256 + Salt; hỗ trợ chuyển tab vai trò linh hoạt.
3. **Customer Home Tab:** Lời chào cá nhân hóa, nút chọn 4 dòng xe nhanh, banner cuốc xe đang chạy thời gian thực, banner nhắc nhở đánh giá 5 sao & e-POD, chatbot logistics AI.
4. **Step 1 - Lộ trình & Bản đồ:** Nhập địa chỉ lấy hàng và tối đa 4 điểm giao hàng, bản đồ OSRM toàn màn hình, kéo ghim bản đồ tự dịch địa chỉ tiếng Việt, chọn từ sổ địa chỉ đã lưu.
5. **Step 2 - Kiện hàng & Trợ lý AI:** Chọn 4 dòng xe, nhập kích thước & khối lượng, kích hoạt Google Gemini AI Cargo Advisor tư vấn chọn xe, điền thông tin người nhận đa điểm, chụp ảnh hàng.
6. **Step 3 - Tính cước & Thanh toán:** Bảng giá động thời gian thực từ Cloud, chọn Voucher khuyến mãi, chọn cổng COD / QR MoMo / QR ZaloPay, cơ chế chống nhấp đúp khi tạo đơn.
7. **Order Detail & Tracking Screen:** Bản đồ Live GPS 60 FPS, HUD tài xế, Gọi thoại Agora VoIP nội bộ, Chat trong chuyến, Hủy đơn kèm lý do, Xem biên bản e-POD và đánh giá 2 chiều.
8. **Customer Orders History Tab:** Quản lý đơn theo các tab trạng thái, chức năng đặt lại đơn 1 chạm (Rebook).
9. **Notification Center Screen:** Thông báo tương tác thật về trạng thái cuốc xe, khuyến mãi mới, tự động đánh dấu đã đọc.
10. **Customer Profile Screen:** Chỉnh sửa hồ sơ, sổ địa chỉ quen thuộc (Nhà riêng, Kho, Công ty), nút hotline 1900 6868 gọi điện thoại thật, công tắc chuyển nhanh sang giao diện Tài xế.

#### 5.3.2 Phân hệ Ứng dụng Đối tác Tài xế (Driver App)
1. **Driver Home Tab & Radar:** Bản đồ vị trí tài xế, công tắc Bật/Tắt Online, Radar quét đơn theo bán kính tùy chọn (≤5km, ≤10km, ≤20km, Tất cả), cảnh báo ký quỹ 15%.
2. **Incoming Order Modal Sheet:** Bảng thông tin cuốc xe mới đổ chuông, hiển thị chi tiết lộ trình, quãng đường, cước phí thực nhận (85%), nhãn COD/Ví và nút chấp nhận cuốc.
3. **Turn-by-Turn HUD Navigation:** Bản đồ dẫn đường Turn-by-Turn OSRM kiểu Google Maps, icon rẽ tiếp theo, tên đường, tự động tính lại đường (Rerouting) khi đi lệch tuyến.
4. **Pickup Photo Confirmation:** Giao diện chụp ảnh kiện hàng bốc lên xe tại điểm lấy hàng.
5. **Touchscreen e-POD Signature Screen:** Màn hình chụp ảnh giao hàng thành công tại điểm đến kết hợp khung ký tên cảm ứng trực tiếp (Touchscreen Signature) có Watermark GPS.
6. **Driver Wallet & Earnings Tab:** Quản lý số dư Ví Thu Nhập và Ví Ký Quỹ riêng biệt; hiển thị thu nhập hôm nay, số cuốc chạy; nạp/rút tiền linh hoạt.
7. **Driver Account & Settings Tab:** Xem hồ sơ đối tác, biển số xe, tải trọng, điểm đánh giá sao, công tắc chuyển nhanh sang giao diện Khách hàng hoặc Mobile Admin.

#### 5.3.3 Phân hệ Quản trị Trung tâm (Web Admin Portal & Mobile Admin)
1. **Dashboard KPI Overview:** Thẻ KPI thời gian thực, biểu đồ doanh thu theo tuần/tháng bằng Recharts, biểu đồ tỷ lệ hoàn tất đơn hàng.
2. **Live Fleet Map Screen:** Bản đồ Leaflet toàn màn hình hiển thị toàn bộ xe đang hoạt động, công nghệ Marker Clustering gom cụm xe mượt mà.
3. **Orders Management & e-POD Audit:** Bảng dữ liệu toàn bộ đơn hàng với bộ lọc đa tiêu chí, cửa sổ xem chi tiết lộ trình và biên bản e-POD có chữ ký đối soát.
4. **Driver KYC Management:** Danh sách tài xế, duyệt hồ sơ KYC mới (CCCD 2 mặt, Giấy phép lái xe), khóa/mở tài khoản.
5. **Dynamic Pricing Engine Configuration:** Form điều chỉnh cước mở cửa, đơn giá/km, phụ phí giờ cao điểm; cập nhật tức thời xuống Mobile App qua `PricingConfigService`.
6. **Voucher Management Screen:** Tạo và quản lý mã Voucher (mức giảm, hạn dùng, điều kiện tối thiểu) lưu trực tiếp lên Firestore `vouchers`.
7. **Incidents Management Screen:** Tiếp nhận, phân loại và xử lý các khiếu nại phát sinh từ cuốc xe giao hàng.

### 5.4 Giao diện phần mềm & Tích hợp Dịch vụ (Software Interfaces)
- **Tích hợp Bản đồ OSRM & OpenStreetMap:** Sử dụng giao thức HTTP REST API định tuyến lộ trình, tính toán khoảng cách và thời gian di chuyển (ETA); Nominatim Geocoding tiếng Việt.
- **Tích hợp Viễn thông Thoại Agora RTC VoIP:** Sử dụng Agora RTC Voice Engine SDK với token động bảo mật, giao thức UDP đảm bảo chất lượng âm thanh ổn định, không nghẽn mạng.
- **Tích hợp Trí tuệ Nhân tạo Google Gemini AI:** Kết nối trực tiếp với Google Generative Language API phân tích hình học kiện hàng và giải đáp nghiệp vụ logistics.
- **Hạ tầng Dữ liệu Firebase Cloud Firestore:** Kết nối trực tiếp 2 chiều thông qua Firestore SDK trên Mobile và Firestore REST API trên Web Admin, dữ liệu đồng bộ tức thời không độ trễ.

---

## 6. Yêu cầu phi chức năng (Non-functional Requirements)

### 6.1 Hiệu năng (Performance)
- **Độ mượt Bản đồ (Frame Rate):** Tần số làm mới vị trí di chuyển của tài xế trên bản đồ đạt chuẩn mượt mà 60 FPS thông qua thuật toán nội suy tọa độ.
- **Độ trễ Dịch vụ (Latency):** Thời gian phản hồi tính toán lộ trình OSRM < 500ms; độ trễ đàm thoại cuộc gọi Agora VoIP < 200ms; độ trễ cập nhật trạng thái Firestore < 100ms.
- **Tối ưu Tài nguyên & Dung lượng:** Thời gian khởi động ứng dụng (Cold start) < 2.0 giây; dung lượng file APK bản phát hành tối ưu riêng cho kiến trúc 64-bit arm64-v8a chỉ ~101 MB (đã giảm hơn 60% so với bản fat APK 255 MB).

### 6.2 Độ tin cậy & Bảo mật (Reliability & Security)
- **Mã hóa Mật khẩu Chuẩn An ninh:** 100% mật khẩu người dùng được băm một chiều bằng thuật toán SHA-256 kết hợp chuỗi Salt bí mật trước khi lưu trữ hoặc truyền tải; không bao giờ lưu mật khẩu dạng thô.
- **Phân quyền Vai trò Nghiêm ngặt:** Áp dụng cơ chế phân quyền chặt chẽ trên Cloud Firestore (Security Rules), kiểm tra tính hợp lệ của token và quyền hạn tương ứng của từng vai trò.
- **Khả năng Phục hồi khi Rớt mạng (Offline Resilience):** Tích hợp cơ chế bộ nhớ đệm cục bộ (Local Cache) trên SQLite/SharedPreferences, cho phép ứng dụng tự động khôi phục chuyến xe đang chạy khi mất sóng hoặc ứng dụng bị tắt đột ngột.
- **Tiêu chuẩn Mã nguồn & Biên dịch:** Dự án đạt tiêu chuẩn chất lượng mã nguồn cao nhất: lệnh kiểm tra mã nguồn `flutter analyze` đạt **0 lỗi (0 issues found)**; lệnh build Web Admin Portal đạt **0 lỗi biên dịch**.

---

## 7. Kết luận (Conclusion)
Tài liệu Đặc tả Yêu cầu Phần mềm (SRS) phiên bản 2.0 này đã phản ánh chính xác 100% cấu trúc kiến trúc, tính năng nghiệp vụ, mô hình dữ liệu và các công nghệ đột phá đang hoạt động trong toàn bộ hệ sinh thái **GoShip Logistics**. 

Với sự kết hợp chặt chẽ giữa Ứng dụng Di động Flutter đa vai trò, Cổng Quản trị Web Admin Portal hiện đại, hạ tầng dữ liệu thời gian thực Firebase Cloud Firestore, công nghệ đàm thoại viễn thông Agora RTC VoIP và Trí tuệ nhân tạo Google Gemini AI Cargo Advisor, GoShip Logistics đã vươn lên trở thành một hệ thống giao nhận chặng cuối hoàn chỉnh, tiệm cận các tiêu chuẩn phần mềm thương mại thực tế và đáp ứng xuất sắc các tiêu chí đánh giá Đồ án Tốt nghiệp.
