# Vortex
Một loại thuốc vô cùng đặc biệt cho phần mềm màu xanh lá hay vẽ vẽ mấy cái hợp chất.
Được viết bằng Ruby.

[Nhấn vào đây để tải (khuyên dùng)](https://github.com/fx09-release/v3rt6x_release/releases/tag/1.2).

## Cách compile (dành cho những ai muốn làm thủ công)
Mình dùng hai công cụ khác nhau để compile cho hai hệ điều hành khác nhau. Với Windows, mình dùng [ocran](https://github.com/Largo/ocran). Còn với macOS, mình dùng [tebako](https://github.com/tamatebako/tebako).


1. Windows:

    Sau khi tải ocran cũng như dựng env thích hợp, đơn giản chỉ chạy ```ocran patchW.rb``` và thêm các aug nếu cảm thấy cần thiết.

2. macOS

    Lưu ý: Cần cài đặt/hạ cấp (nếu đã cài các phiên bản mới hơn) Xcode 16.2 và cmake 3.31.6. 
    
    Tạm thời đừng cập nhật Xcode cũng như Command Line Tools lên 16.3 vì libc++ gần đây không còn hỗ trợ ```std::allocator<const T>``` 
    nên gây ra lỗi khi compile cho ```folly``` (một thư viện cần thiết cho tebako). Ngoài ra, **tebako cần cmake v3** (cụ thể là v3.20 - v3.31.6) để có thể hoạt động ổn định (nếu bạn tự chỉnh CMakeLists.txt trong mã nguồn và tự compile luôn tebako thông qua ```gem build``` thì tốt.)

   Nhớ  ```export PATH="$(brew --prefix bison)/bin:$PATH"``` trong thông qua lệnh ```nano ~/.zshrc```.
    
    Chạy ```tebako setup``` để cache các thư viện cần thiết. Sau đó chạy ```tebako press -e <tới đường dẫn file .rb (trong trường hợp này là patchM.rb)> -r <tới thư mục root (thư mục này tuỳ chọn)>```.

    Lưu ý: Mình không khuyến khích dùng lệnh ```sudo``` cho bất kỳ thao tác compile. Các bạn nên dựng môi trường thích hợp để có thể code mà không cần đến quyền root.


