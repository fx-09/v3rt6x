# encoding: ASCII-8Bit

system("title ChemOffice Suite 18.0-25.0.2 Patcher (v0rt3x) by Đức Lê.")
Dir.chdir(File.dirname($Exerb ? ExerbRuntime.filepath : __FILE__)) # change currentDir to the file location

@total = [0, 0, 0, 0, 0, 0] # number of [all, patched, restored, ignored, failed, patial] files
@pattern = [['2d 04 17 0a 2b 02', '0a 06 0b 07 2a', 0x16, 0x17, 'IsValidatedBy_#1'], ['33 04 17 0a 2b 04 2b ..', '0a 06 2a', 0x16, 0x17, 'IsValidatedBy_#2'], ['04 54 17 0c 2b 04 2b ..', '0c 08 2a', 0x16, 0x17, 'IsValidatedBy_#3'], ['14 0b 7e ..{4}', '07 17 0a 38 ..{4}', 0x2c, 0x2d, 'StartNetworkYell']]

class String  # backward compatibility w/ Ruby < 1.9
  define_method(:getbyte) {|i| self[i]} unless String.method_defined?(:getbyte)
end

def patch(filename, mode)
  f = open(filename, 'r+b')
  related = false
  missing = false
  found = [false]*4 # Filter 2 a/b/... met
  ignore = [false]*4
  indices = [-6, -4, -4, 7] # note the last one is different from others; its actual offset will be calculated later
  tempMode = mode
  while not f.eof?
    d = f.gets(sep="\x2a") # read until met with 0x2a (retn)
    next if d.size < 42 # Filter 1
    if d[-5, 5] == "\x0a\x06\x0b\x07\x2a" and d[-12, 6] == "\x2d\x04\x17\x0a\x2b\x02" # Filter 2a
      i = 0
    elsif d[-3, 3] == "\x0a\x06\x2a" and d[-12, 7] == "\x33\x04\x17\x0a\x2b\x04\x2b" # Filter 2b
      i = 1
    elsif d[-3, 3] == "\x0c\x08\x2a" and d[-12, 7] == "\x04\x54\x17\x0c\x2b\x04\x2b" # Filter 2c
      i = 2
    elsif (offset=d.index("\x14\x0b\x7e")) && d[offset+8, 4] == "\x07\x17\x0a\x38" # Filter 2d
      i = 3
      indices[i] += offset - d.size
    else
      next
    end
    case (b=d.getbyte(indices[i]))
    when @pattern[i][3]
      patched = true
    when @pattern[i][2]
      patched = false
    else
      next
    end
    f.seek(indices[i], 1)
    if found[i] # already met
      puts "\e[1;31mMẫu trùng lặp được tìm thấy ở offset 0x#{f.tell.to_s(16)} cho func\e[0m #{@pattern[i][4]} [#{@pattern[i][0]} \e[7m..\e[0m #{@pattern[i][1]}]."
      missing = true
      next
    end
    unless found.any? # first time met
      related = true
      puts "\n\e[4m#{filename}\e[0m"
    end
    found[i] = true
    print "\e[1;33m#{patched ? 'Mẫu đã vá      ' : 'Mẫu sắp được vá'}\e[0m [#{@pattern[i][0]} \e[7m#{b.to_s(16)}\e[0m #{@pattern[i][1]}] cho func #{@pattern[i][4]} \e[1;33mđược tìm thấy tại offset 0x#{f.tell.to_s(16)}\e[0m "
    if tempMode == 'A'
      print "\nChọn chế độ: \e[4m[V]á\e[0m hoặc \e[4m[H]oàn tác\e[0m"
      print(tempMode = `choice /T 10 /C VH /D V /N`.chomp.upcase)
    end
    if patched
      if tempMode == 'H'
        f.putc(@pattern[i][2])
        puts "\e[1;33m: Hoàn tác thành công.\e[0m"
      else
        puts ": Đã bỏ qua."
        ignore[i] = true
      end
    else
      if tempMode == 'R'
        puts ": Đã bỏ qua."
        ignore[i] = true
      else
        f.putc(@pattern[i][3])
        puts "\e[1;32m: Vá thành công.\e[0m"
      end
    end
  end
  if related
    for j in 0...found.size
      unless found[j]
        missing = true
        puts "\e[1;31mKhông tìm thấy func\e[0m #{@pattern[j][4]} [#{@pattern[j][0]} \e[7m..\e[0m #{@pattern[j][1]}]."
      end
    end
    @total[0] += 1
    if missing
      @total[5] += 1
    elsif ignore.all?
      @total[3] += 1
    else
      @total[tempMode=='R' ? 2 : 1] += 1
    end
  end
  f.close
rescue # error
  puts "\e[1;31mĐã phát sinh lỗi:"
  @total[4] += 1
  puts $!.inspect; puts $@.inspect
  print "\e[0m"
end

listVer = [[], []]
puts "\nBạn đã cài đặt:"
for i in 0..1 # check 32-bit and 64-bit registry
  list = ''
  print "  \e[1;33m#{(i+1)*32}-bit ChemOffice\e[0m "
  ['ChemOffice ', 'ChemDraw Suite', 'Revvity ChemDraw'].each {|n|
    ['HKLM', 'HKCU'].each {|j| list +=  `reg query #{j}\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall /s /t REG_SZ /f "#{n}" /reg:#{(i+1)*32} 2>nul`}} # check CurrentUser and LocalMachine ("ChemOffice " the space is necessary to exclude ChemOffice+; ChemDraw Suite is for version >= 23)
  for k in list.split("\n\n")
    next unless k.include?('DisplayName')
    key = k.strip.split("\n")[0]
    ['DisplayName', 'VersionMajor', 'VersionMinor', 'InstallLocation'].each {|l| listVer[i] << `reg query \"#{key}\" /v #{l} /reg:#{(i+1)*32} 2>nul`.strip.split('  ')[-1]}
    (1..2).each {|l| eval "listVer[i][l] = #{listVer[i][l]}"} # convert to integer
    print "[#{listVer[i][0]}, Version #{listVer[i][1]}.#{listVer[i][2]}] được cài ở\n    \e[4m#{listVer[i][3]}\e[0m"
    break
  end
  if listVer[i].empty? then puts "\e[1;31mCHƯA cài đặt!\e[0m"; next end
  if listVer[i][1] < 18
    print " \e[1;31m(KHÔNG HỖ TRỢ PHIÊN BẢN CHEMOFFICE <18)\e[0m"
    listVer[i] = []
  end
  puts
end
print "\nThông tin này có đúng không? [C/K] (\e[1;32mNhấn 'C' hoặc chờ 10 giây\e[0m để xác nhận; hoặc nhấn 'K' trong vòng 10 giây để huỷ xác nhận và tự nhập đường dẫn.) "
puts(c = `choice /T 10 /C CK /D C /N`.chomp.upcase)
if c=='K'
  for i in 0..1
    puts; puts "Dành cho \e[1;33m#{(i+1)*32}-bit ChemOffice\e[0m:"
    print '  Nhập số phiên bản (e.g. 18.2, 20.0): ____'; print "\b"*4
    v = `cmd /V /C \"set /p var=&& echo !var!\"` # STDIN.gets will not work after calling 'choice'
    listVer[i][1] = v.split('.')[0].to_i
    listVer[i][2] = v.split('.')[1].to_i
    if listVer[i][1] < 18
      puts "  \e[1;31m(KHÔNG HỖ TRỢ PHIÊN BẢN CHEMOFFICE <18)\e[0m"
      listVer[i] = []
    else
      print '  Nhập đường dẫn: _________________________'; print "\b"*25
      listVer[i][3] = `cmd /V /C \"set /p var=&& echo !var!\"`.chomp
    end
  end
end

if listVer[0].empty? and listVer[1].empty? then system('pause'); exit end
print "\nBạn muốn: \e[4m[V]á\e[0m, \e[4m[H]oàn tác\e[0m, hoặc muốn được \e[4m[T]ham vấn\e[0m cho từng file một? (Nhấn V, H, hay T; hoặc chờ 10 giây, phần mềm sẽ mặc định vá ChemOffice.) "
puts(m = `choice /T 10 /C VHT /D V /N`.chomp.upcase)

require 'find'
rename = []; patch = []
exts = ['.exe', '.dll', '.ocx', '.pyd']
for i in 0..1
  next if listVer[i].empty?
  if File.directory?(File.join(listVer[i][3], 'Common'))
    rename << File.join(listVer[i][3], 'Common\DLLs\FlxComm' + '64'*i + '.dll')
    rename << File.join(listVer[i][3], 'Common\DLLs\FlxCore' + '64'*i + '.dll')
  else # 23.0 NA version; dlls stored under installation root dir
    rename << File.join(listVer[i][3], 'FlxComm' + '64'*i + '.dll')
    rename << File.join(listVer[i][3], 'FlxCore' + '64'*i + '.dll')
  end
  next if listVer[i][1] < 19
  Find.find(listVer[i][3]) {|j| patch << j.gsub('/', "\\") if exts.include?(File.extname(j).downcase) and File.basename(j)[0, 5] != 'FlxCo'}
end
rename.each do |i|
  puts "\n\e[4m#{i}\e[0m"
  @total[0] += 1
  if File.exist?(i)
    print "\e[1;32mĐã tìm thấy file .dll\e[0m "
  elsif File.exist?(i+'.bak')
    print "\e[1;33mĐã tìm thấy file .bak\e[0m "
  else
    print "\e[1;31mKhông tìm thấy file nào cả.\e[0m"
    @total[4] += 1
  end
  tempMode = m
  if m == 'T'
    print "\nChọn \e[4m[V]á\e[0m hoặc \e[4m[H]oàn tác\e[0m mode: "
    print(tempMode = `choice /T 10 /C VH /D V /N`.chomp.upcase)
  end
  begin
    if File.exist?(i)
      if tempMode == 'R'
        puts ": Bỏ qua."
        @total[3] += 1
      else
        File.rename(i, i+'.bak')
        puts "\e[1;32m: Đã đổi phần mở rộng từ .dll thành .bak\e[0m"
        @total[1] += 1
      end
    else
      if tempMode == 'R'
        File.rename(i+'.bak', i)
        puts "\e[1;33m: Đã đổi tên thành .dll file.\e[0m"
        @total[2] += 1
      else
        puts ": Bỏ qua."
        @total[3] += 1
      end
    end
  rescue
    puts "\e[1;31mĐã xảy ra lỗi:"
    @total[4] += 1
    puts $!.inspect; puts $@.inspect
    print "\e[0m"
  end
end
patch.each {|i| patch(i, m)}

puts; puts "Trong #{@total[0]} file để crack DRM, \e[1;32m#{@total[1]} đã được vá, \e[1;33m#{@total[2]} đã được hoàn tác, \e[1;31m#{@total[4]} thất bại, \e[1;35m#{@total[5]} có kết quả không như mong đợi, \e[0mand #{@total[3]} được bỏ qua."

if m == 'R' then puts; system('pause'); exit end

for i in 0..1
  next if listVer[i].empty?
  next if listVer[i][1] < 18
  for d in ['HKLM', 'HKCU']
    for n in ['', "#{listVer[i][1]}.#{listVer[i][2]}\\"] # 22.2: ''
      key = "#{d}\\Software\\RevvitySignalsSoftware\\Chemistry"
      if listVer[i][1] > 22 # 23.0: confirm licensing method
        `reg add #{key} /f /reg:#{(i+1)*32}`
        `reg add #{key} /v LicensingService.LicenseSystem /t REG_SZ /d flexera /f /reg:#{(i+1)*32}`
      end
      for m in ['RevvitySignalsSoftware', 'PerkinElmerInformatics'] # 23.0: 'RevvitySignalsSoftware'
        key = "#{d}\\Software\\#{m}\\ChemBioOffice\\#{n}Ultra"
        `reg add #{key} /f /reg:#{(i+1)*32}`
        `reg add #{key} /v \"Activation Code\" /t REG_SZ /d 6UE-7IMW3-5W-QZ5P-J3PCX-OHDX-35GRN /f /reg:#{(i+1)*32}`
        `reg add #{key} /v \"Serial Number\" /t REG_SZ /d 875-385499-9864 /f /reg:#{(i+1)*32}`
        `reg add #{key} /v Success /t REG_SZ /d True /f /reg:#{(i+1)*32}`
      end
    end
  end
end

puts "\nĐã thay đổi Registry. \e[1;32mĐÃ HOÀN THÀNH CÔNG VIỆC.\e[0m\nTuỳ chọn: Vui lòng nhập \e[4thông tin cá nhân\e[0m (bỏ trống cũng được)!" unless m == 'H'

info = ['', '', '']
print '  Tên người dùng:    _______________'; print "\b"*15
info[0] = `cmd /V /C \"set /p var=&& echo !var!\"`.chomp
print '  Email:        _______________'; print "\b"*15
info[1] = `cmd /V /C \"set /p var=&& echo !var!\"`.chomp
print '  Tổ chức: _______________'; print "\b"*15
info[2] = `cmd /V /C \"set /p var=&& echo !var!\"`.chomp

for i in 0..1
  next if listVer[i].empty?
  next if listVer[i][1] < 18
  for d in ['HKLM', 'HKCU']
    for n in ['', "#{listVer[i][1]}.#{listVer[i][2]}\\"] # 22.2: ''
      for m in ['RevvitySignalsSoftware', 'PerkinElmerInformatics'] # 23.0: 'RevvitySignalsSoftware'
        key = "#{d}\\Software\\#{m}\\ChemBioOffice\\#{n}Ultra"
        `reg add #{key} /v \"User Name\" /t REG_SZ /d \"#{info[0]}\" /f /reg:#{(i+1)*32}`
        `reg add #{key} /v Email /t REG_SZ /d \"#{info[1]}\" /f /reg:#{(i+1)*32}`
        `reg add #{key} /v Organization /t REG_SZ /d \"#{info[2]}\" /f /reg:#{(i+1)*32}`
      end
    end
  end
end
puts; system('pause')
