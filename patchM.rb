#!/usr/bin/env ruby
# encoding: ASCII-8Bit
# ruby 2.0.0
require 'io/console'
print "\033]0;Thuốc đặc trị ChemDraw 17~25 (Vortex on macOS) by Đức Lê.4\007"

def removeAllSig(filename)
    puts "\e[1;33mĐang xử lý\e[0m #{filename}..."
    f = open(filename, "r+b") # read and write, binary
    if f.read(4) == "\xCA\xFE\xBA\xBE" # Mach-O Fat Binary
        n = f.read(4).unpack('N')[0] # fat_arch_size; big-endian
        o = Array.new(n, 0)
        s = Array.new(n, 0)
        for i in 0...n
            f.seek(8, 1) # skip arch cpu_(sub_)type
            o[i], s[i] = f.read(8).unpack('N2') # arch file_offsset; size
            f.seek(4, 1) # skip alignment
        end
        for i in 0...n
            puts "\e[1;32mĐã tìm thấy binary Mach-O\e[0m @ 0x#{o[i].to_s(16)} (+ 0x#{s[i].to_s(16)})"
            removeSig(f, o[i], s[i])
        end
    else
        removeSig(f, 0, File.size(f))
    end
    f.close
rescue # error
    puts "\e[1;Phát sinh lỗi:\e[0m"
    puts $!.inspect
    puts $@.inspect
end

def removeSig(f, offset, size)
    f.seek(offset)
    if f.read(4) != "\xCF\xFA\xED\xFE" # Mach-O binary
        puts "\e[1;33mLưu ý: Đây không phải là binary Mach-O @ 0x#{offset.to_s(16)}. Bạn tải ChemDraw từ đúng nguồn chính thống chưa?\e[0m"
        return
    end
    c = f.read(4)
    if c == "\7\0\0\1" # cpu_type==x86_64
      @must_code_sign = false
    elsif c == "\x0C\0\0\1" # cpu_type==ARM64
      @need_code_sign = true
    end
    f.seek(8, 1)
    tmp = f.read(16) # now at: end of mach head
    ncmd, cmdSize = tmp.unpack('L2')
    if cmdSize+32 > size
        puts "\e[1;33mCảnh báo: Đã đọc đến EOF nhưng vẫn chưa tìm ra trình tự. Bạn tải ChemDraw từ đúng nguồn chính thống chưa?\e[0m"
        return
    end
    f.seek(cmdSize-16, 1)
    tmp = f.read(16) # end of load cmd
    if tmp[0, 4] != "\x1d\0\0\0" # LC_CODE_SIGNATURE
        puts "\e[1;33mCảnh báo: Không phát hiện ra chữ ký. Bạn có tải ChemDraw từ đúng nguồn chính thống chưa?\e[0m"
        return
    end
    sigOffset, sigSize = tmp[8, 8].unpack('L2')
    if sigOffset+sigSize > size
        puts "\e[1;33mCảnh báo: Đã đọc đến EOF (end-of-file) nhưng vẫn chưa tìm ra trình tự. Bạn tải ChemDraw từ đúng nguồn chính thống chưa?\e[0m"
        return
    end
    puts "\e[1;32mPhát hiện DRM.\e[0m @ 0x#{sigOffset.to_s(16)} (+ 0x#{sigSize.to_s(16)})"
    print "\e[1;32mBạn có muốn \e[7mTHUỐC\e[0m chứ [c/K]?"
    if STDIN.getch.downcase == 'c'
        f.seek(-16, 1)
        f.write("\0"*16) # end of load cmd
        f.seek(16+offset)
        f.write([ncmd-1, cmdSize-16].pack('L2'))
        f.seek(sigOffset+offset)
        f.write("\0"*sigSize)
        puts "\e[1;32mLoại bỏ DRM thành công.\e[0m"
        return
    end
    @need_code_sign = false # cancelled
    puts("\e[1;33mKhông có thao tác nào được thực hiện.\e[0m")
rescue # error
    @need_code_sign = false # cancelled
    puts "\e[1;31mĐã phát sinh lỗi:\e[0m"
    puts $!.inspect
    puts $@.inspect
end

def patchAll(filename) # FNEActivationHelperMac::GetActivatedSKUAndProductLevel {return 0}
    puts "\e[1;33mĐang xử lý\e[0m #{filename}..."
    f = open(filename, "r+b") # read and write, binary
    @times = @byte = 0 # number of to-be-patched patterns, processed length

    d = f.read(8)
    if d[0, 4] == "\xCA\xFE\xBA\xBE" # Mach-O Fat Binary
        _, n = d.unpack('N2') # fat_arch_size; big-endian
        o1 = s1 = o2 = s2 = 0
        for i in 0...n
            c = f.read(4) # arch cpu_type
            f.seek(4, 1) # skip arch cpu_sub_type
            o, s = f.read(8).unpack('N2') # arch file_offsset; size
            f.seek(4, 1) # skip alignment
            if c == "\1\0\0\7" and o1.zero?
                o1 = o; s1 = s
            elsif c == "\1\0\0\x0C" and o2.zero?
                o2 = o; s2 = s
            else
                puts "\e[1;33mĐã bỏ qua: Binary Mach-O của loại kiến trúc CPU không được hỗ trợ [0x#{c.unpack('H*')[0]}] đã được tìm thấy\e[0m @ 0x#{o.to_s(16)} (+ 0x#{s.to_s(16)})"
            end
        end
        if o1 != 0
          puts "\e[1;32mBinary Mach-O loại [x86_64] đã được tìm thấy\e[0m @ 0x#{o.to_s(16)} (+ 0x#{s.to_s(16)})"
          patchX86(f, o1, o1+s1)
        end
        if o2 != 0
          puts "\e[1;32mBinary Mach-O loại [ARM64] đã được tìm thấy\e[0m @ 0x#{o.to_s(16)} (+ 0x#{s.to_s(16)})"
          patchARM(f, o2, o2+s2) if o2 != 0
        end
    elsif d == "\xCF\xFA\xED\xFE\7\0\0\1" # Mach-O binary and cpu_type==x86_64
        patchX86(f, 0, File.size(f))
    elsif d == "\xCF\xFA\xED\xFE\x0C\0\0\1" # Mach-O binary and cpu_type==ARM64
        patchARM(f, 0, File.size(f))
    else
        puts "\e[1;33mCảnh báo: Đây không phải là binary Mach-O hoặc kiến trúc CPU không được hỗ trợ. Bạn tải ChemDraw từ đúng nguồn chính thống chưa?\e[0m"
    end
    f.close
    if @times.zero?
        # not applicable
        puts "\e[1;33mKhông tìm thấy trình tự hoặc người dùng dừng tiến trình.\e[0m"
    else
        puts "\e[1;33mĐã xử lý/hoàn nguyên #{@times} lần trong file này.\e[0m"
    end
rescue # error
    puts "\e[1;31mPhát sinh lỗi:\e[0m"
    puts $!.inspect
    puts $@.inspect
end

def patchX86(f, offset, offset_max)
    puts "\e[1;33mĐang xử lý kiến trúc x86_64\e[0m..."
    f.seek(offset)
    loop do
        maxlen = offset_max-f.pos
        b = f.gets("\xC3", maxlen) # read until met with 0xC3 (RET); do not read further than `offset_max`
        break if b.nil? # EOF
        len = b.size # read length
        break if len == maxlen # EOF
        byte = (f.pos / 104857.6).to_i
        print "\r\e[1;33mĐã thực hiện được %.1f MB.\e[0m " % (byte/10.0) if byte != @byte
        @byte = byte
        
        next if len < 30
        if b[-26, 4] == "\x48\x89\x1f\xe8" and # mov [rdi], rbx; call ...
           b[-12].ord < 0x30 # add rsp, 28h [There are multiple functions that matches with the above pattern, so need to restrict more; this function only needs to add 28 bytes to balance the stack, while others requires more
        # Ver 25: 48 8D 7D C8 48 89 1F E8 ..{4} 44 89 F0 48 83 C4 28 5B 41 5C 41 5D 41 5E 41 5F 5D C3
            case b[-18, 3]
            when "\x44\x89\xf0" # to-patch
                puts "\e[1;32m\rĐã tìm ra trình tự\e[0m @ 0x#{f.pos.to_s(16)}, MOV EAX, R14D -> XOR EAX, EAX: 48 89 C6 1F E8 ..{4} \e[7m44 89 F0\e[0m ..{14} C3 => \e[7m31 C0 90\e[0m"
                print "\e[1;32mBạn có muốn \e[7mCRACK\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user
                f.seek(-18, 1); f.write("\x31\xc0\x90"); f.seek(15, 1)
            when "\x31\xc0\x90" # patched
                puts "\e[1;34m\rĐã tìm ra trình tự\e[0m @ 0x#{f.pos.to_s(16)}, XOR EAX, EAX -> MOV EAX, R14D: 48 89 C6 1F E8 ..{4} \e[7m31 C0 90\e[0m ..{14} C3 => \e[7m44 89 F0\e[0m"
                print "\e[1;34mBạn có muốn \e[7mHOÀN TÁC\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user
                f.seek(-18, 1); f.write("\x44\x89\xf0"); f.seek(15, 1)
            else next
            end
        elsif b[-30, 3] == "\x41\x89\xc6"
        # Ver 18..23: 41 89 C6 48 8D 7D B8 ..{5} 44 89 F0 48 83 C4 28 5B 41 5C 41 5D 41 5E 41 5F 5D C3
            case b[-18, 3]
            when "\x44\x89\xf0" # to-patch
                puts "\e[1;32m\rĐã tìm ra mẫu:\e[0m @ 0x#{f.pos.to_s(16)}, MOV EAX, R14D -> XOR EAX, EAX: 41 89 C6 ..{9} \e[7m44 89 F0\e[0m ..{14} C3 => \e[7m31 C0 90\e[0m"
                print "\e[1;32mBạn có muốn \e[7mTHUỐC\e[0m chứ [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user.
                f.seek(-18, 1); f.write("\x31\xc0\x90"); f.seek(15, 1)
            when "\x31\xc0\x90" # patched
                puts "\e[1;34m\rĐã tìm ra mẫu:\e[0m @ 0x#{f.pos.to_s(16)}, XOR EAX, EAX -> MOV EAX, R14D: 41 89 C6 ..{9} \e[7m31 C0 90\e[0m ..{14} C3 => \e[7m44 89 F0\e[0m"
                print "\e[1;34mBạn có muốn \e[7mHOÀN TÁC\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user.
                f.seek(-18, 1); f.write("\x44\x89\xf0"); f.seek(15, 1)
            else next
            end
        elsif b[-28, 3] == "\x45\x31\xe4"
        # Ver 17: 45 31 E4 48 8D 7D B0 ..{5} 44 88 E0 48 83 C4 40 5B 41 5C 41 5E 41 5F 5D C3
            case b[-16, 3]
            when "\x44\x88\xe0" # to-patch
                puts "\e[1;32m\rĐã tìm ra mẫu:\e[0m @ 0x#{f.pos.to_s(16)}, MOV AL, R12B -> MOV AL, 0x01: 45 31 E4 ..{9} \e[7m44 88 E0\e[0m ..{12} C3 => \e[7mB0 01 90\e[0m"
                print "\e[1;32mBạn có muốn \e[7mTHUỐC\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user.
                f.seek(-16, 1); f.write("\xb0\x01\x90"); f.seek(13, 1)
            when "\xb0\x01\x90" # patched
                puts "\e[1;34m\rĐã tìm ra mẫu\e[0m @ 0x#{f.pos.to_s(16)}, MOV AL, 0x01 -> MOV AL, R12B: 45 31 E4 ..{9} \e[7mB0 01 90\e[0m ..{12} C3 => \e[7m44 88 E0\e[0m"
                print "\e[1;34mBạn có muốn \e[7mHOÀN TÁC\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user.
                f.seek(-16, 1); f.write("\x44\x88\xe0"); f.seek(13, 1)
            else next
            end
        else next # not a to-be-patched pattern; roll back.
        end
        @times += 1
        puts "\e[1;33mĐã xử lý xong.\e[0m"
        return # there are multiple patterns; however, only the first one is what we desire
    end
    puts "\e[1;33mKhông có tiến trình nào được thực hiện.\e[0m"
rescue # error
    puts "\e[1;31mĐã phát hiện lỗi:\e[0m"
    puts $!.inspect
    puts $@.inspect
end

def patchARM(f, offset, offset_max)
    puts "\e[1;33mĐang xử lý kiến trúc ARM64\e[0m..."
    f.seek(offset)
    loop do
        maxlen = offset_max-f.pos
        b = f.gets("\xC0\x03\x5F\xD6", maxlen) # read until met with C0 03 5F D6 (RET); do not read further than `offset_max`
        break if b.nil? # EOF
        len = b.size # read length
        break if len == maxlen # EOF
        byte = (f.pos / 104857.6).to_i
        print "\r\e[1;33mĐã xử lý %.1f MB.\e[0m " % (byte/10.0) if byte != @byte
        @byte = byte
        
        next if len < 45
        if b[-45, 5] == "\x97\xF3\x03\x00\xAA" # BL ...; MOV X19, X0
        # Ver 25:  BL <xxxToLevCode>; MOV X19, X0; ...; BL <destroy_vector>; MOV X0, X19; LDP X29, X30, ...; ADD SP, SP, #0x70; RET
            case b[-28, 4]
            when "\xE0\x03\x13\xAA" # to-patch
                puts "\e[1;32m\rĐã tìm ra trình tự\e[0m @ 0x#{f.pos.to_s(16)}, MOV X0, X19 -> MOV X0, #0: 97 F3 03 00 AA ..{12} \e[7mE0 03 13 AA\e[0m ..{20} C0 03 5F D6 => \e[7m00 00 80 D2\e[0m"
                print "\e[1;32mBạn có muốn \e[7mCRACK\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user
                f.seek(-28, 1); f.write("\x00\x00\x80\xD2"); f.seek(24, 1)
            when "\x00\x00\x80\xD2" # patched
                puts "\e[1;34m\rĐã tìm ra trình tự\e[0m @ 0x#{f.pos.to_s(16)}, MOV X0, #0 -> MOV X0, X19: 97 F3 03 00 AA ..{12} \e[7m00 00 80 D2\e[0m ..{20} C0 03 5F D6 => \e[7mE0 03 13 AA\e[0m"
                print "\e[1;34mBạn có muốn \e[7mPHỤC HỒI\e[0m không [c/K]? "
                break if STDIN.getch.downcase == 'k' # canceled by user
                f.seek(-28, 1); f.write("\xE0\x03\x13\xAA"); f.seek(24, 1)
            else next
            end
        else next # not a to-be-patched pattern; roll back
        end
        @times += 1
        puts "\e[1;33mĐã xử lý xong.\e[0m"
        return # there are multiple patterns; however, only the first one is what we desire
    end
    puts "\e[1;33mKhông có tiến trình nào được thực hiện.\e[0m"
rescue # error
    puts "\e[1;31mĐã phát sinh lỗi:\e[0m"
    puts $!.inspect
    puts $@.inspect
end

# Main
@vers = 0 # total number of versions of ChemDraw
Dir.entries('/Applications').each do |i|
    next unless i.include?('ChemDraw')
    puts; print "\e[7m"; puts '-'*50; puts i.sub('.app', '').ljust(50); puts '-'*50; print "\e[0m"
    ver = i[/\d+\.?\d*/].to_f
    s = File.join('/Applications', i, 'Contents/MacOS/ChemDraw')
    if ver < 17
        puts "\e[1;31mKhông phù hợp (Phiên bản #{ver} < 17)\e[0m"; next
    elsif ver < 18
        f = s
    else
        f = File.join('/Applications', i, 'Contents/Frameworks/ChemDrawBase.framework/Versions/A/ChemDrawBase')
    end
    if File.exist?(f) and File.exist?(s)
        @need_code_sign = false
        @must_code_sign = true
        removeAllSig(s); patchAll(f); @vers += 1
        if @need_code_sign
            puts "\n\e[1;31mLƯU Ý: Cần thao tác thêm để có thể hoàn thành. Vui lòng đọc những dòng dưới đây vô cùng cẩn thận (coi như năn nỉ).\e[0m\n\nBắt đầu từ phiên bản ChemDraw 25.0 trở đi, phần mềm đã chính thức hỗ trợ các loại Macbook có kiến trúc ARM64 (nói gọn là Mac có bộ vi xử lý Apple Silicon M1 M2 gì đó trở đi); tuy nhiên, phiên bản MacOS > 10 yêu cầu một chữ ký hợp lệ (còn được gọi là signature) thì ứng dụng trên ARM64 mới chạy được."
            if @must_code_sign
                puts "\e[1;33mTóm lại, ChemDraw phải được codesign.\e[0m Nhấn bất kỳ phím nào để chạy lệnh 'codesign' trên máy của bạn."
                STDIN.getch
            else
                puts "1. Nếu bạn đang dùng Mac chạy chip Intel (các dòng từ 2020 đổ về trước), coi như bạn đã hoàn tất! Mở ChemDraw dùng bình thường.\n2. Ngoài ra, bạn có thể mở ChemDraw bằng Rosetta (Google 'Rosetta' nếu bạn không biết nó là gì); ChemDraw vẫn sẽ hoạt động bình thường .\n3. Nếu bạn không dùng/không biết mở Rosetta trên Mac ARM64, ChemDraw phải được codesign thì mới chạy được. \e[1;33mDùng lệnh `codesign` để hoàn tất luôn nhé?\e[0m [c/K]?\e[1;31m"
                next if STDIN.getch.downcase != 'y'
            end
            system("codesign --force --deep -s - \"#{s}\"
if [ \"$?\" -eq 0 ]; then echo \"\e[1;32mSign thành công.\e[0m\"; else echo \"Sign không thành công. ChemDraw có thể sẽ không chạy được.\e[0m\"; fi")
        end
    else
        puts "\e[1;31mKhông thực hiện được (không tìm thấy file)\e[0m"
    end
end
puts
if @vers.zero?
    puts "\e[1;31mPhiên bản ChemDraw không phù hợp\e[0m"
else
    puts "\e[1;33mĐã có tổng cộng #{@vers} phiên bản ChemDraw được vá.\e[0m"
end
