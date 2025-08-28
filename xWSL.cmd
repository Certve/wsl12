@ECHO OFF & NET SESSION >NUL 2>&1
IF %ERRORLEVEL% == 0 (ECHO Administrator check passed...) ELSE (ECHO You need to run this command with administrative rights.  Is User Account Control enabled? && pause && goto ENDSCRIPT)
COLOR 1F
SET GITORG=Certve
SET GITPRJ=kalix12
SET BRANCH=main
SET BASE=https://github.com/%GITORG%/%GITPRJ%/raw/%BRANCH%
SET RUNSTART=%date% @ %time:~0,5%
SET DISTRO=kali-linux
START /MIN "Kali" "CMD.EXE" "/C WSLconfig.exe /t %DISTRO% & Taskkill.exe /IM kali.exe /F"

REM ## Enable WSL if needed
PowerShell.exe -Command "dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
PowerShell.exe -Command "dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart"
PowerShell.exe -Command "wsl --set-default-version 2"
PowerShell.exe -Command "$WSL = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' ; if ($WSL.State -eq 'Disabled') {Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux}"

REM ## Install Kali from AppStore if needed
PowerShell.exe -Command "wsl -d kali-linux -e 'uname' > $env:TEMP\DistroTestAlive.TMP ; $alive = Get-Content $env:TEMP\DistroTestAlive.TMP ; IF ($Alive -ne 'Linux') { Start-BitsTransfer https://aka.ms/wsl-kali-linux-new -Destination $env:TEMP\Kali.AppX ; WSL.EXE --set-default-version 1 > $null ; Add-AppxPackage $env:TEMP\Kali.AppX ; Write-Host ; Write-Host 'NOTE: Open the "Kali Linux" app from your Start Menu.' ; Write-Host 'When Kali initialization completes' ; PAUSE ; Write-Host }"

REM ## Acquire LxRunOffline
cp -r D:\a\kalix12\kalix12\* %TEMP% >NUL 2>&1
IF NOT EXIST "%TEMP%\LxRunOffline.exe" POWERSHELL.EXE -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; wget https://github.com/certve/Pi-Hole-for-WSL1/blob/master/LxRunOffline-v3.5.0-33-gbdc6d7d-msvc.zip?raw=true -UseBasicParsing -OutFile '%TEMP%\LxRunOffline.zip' ; Expand-Archive -Path '%TEMP%\LxRunOffline.zip' -DestinationPath '%TEMP%' -Force ; copy '%TEMP%\LxRunOffline-v3.5.0-33-gbdc6d7d-msvc\*.exe' '%TEMP%'" > NUL
REM ## Find system DPI setting and get installation parameters
IF NOT EXIST "%TEMP%\windpi.ps1" POWERSHELL.EXE -ExecutionPolicy Bypass -Command
"cp -r 'D:\a\kalix12\kalix12\windpi.ps1' -UseBasicParsing '%TEMP%\windpi.ps1'"
FOR /f "delims=" %%a in ('powershell -ExecutionPolicy bypass -command "%TEMP%\windpi.ps1" ') do set "WINDPI=%%a"

CLS
ECHO [kalix12 2025.3.1]
ECHO:
ECHO Hit Enter to use your current display scaling in Windows
SET /p WINDPI=or set your desired value (1.0 to 3.0 in .25 increments) [%WINDPI%]: 
SET RDPPRT=3399& SET /p RDPPRT=Port number for kalix12 traffic or hit Enter for default [3399]: 
SET SSHPRT=3322& SET /p SSHPRT=Port number for SSHd traffic or hit Enter for default [3322]: 
FOR /f "delims=" %%a in ('PowerShell -Command 96 * "%WINDPI%" ') do set "LINDPI=%%a"
FOR /f "delims=" %%a in ('PowerShell -Command 32 * "%WINDPI%" ') do set "PANEL=%%a"
FOR /f "delims=" %%a in ('PowerShell -Command 48 * "%WINDPI%" ') do set "ICONS=%%a"
SET DEFEXL=NONO& SET /p DEFEXL=[Not recommended!] Type [X] to eXclude from Windows Defender: 
SET DISTROFULL="%TEMP%"
SET /A SESMAN = %RDPPRT% - 50
CD %DISTROFULL%
%TEMP%\LxRunOffline.exe su -n %DISTRO% -v 0
SET GO="%DISTROFULL%\LxRunOffline.exe" r -n "%DISTRO%" -c

IF %DEFEXL%==X (POWERSHELL.EXE -Command "wget %BASE%/excludeWSL.ps1 -UseBasicParsing -OutFile '%DISTROFULL%\excludeWSL.ps1'" & START /WAIT /MIN "Add exclusions in Windows Defender" "POWERSHELL.EXE" "-ExecutionPolicy" "Bypass" "-Command" ".\excludeWSL.ps1" "%DISTROFULL%" &  DEL ".\excludeWSL.ps1")

REM ## Workaround potential DNS issue in WSL and update Keyring
%GO% "rm -rf /etc/resolv.conf ; echo 'nameserver 1.1.1.1' > /etc/resolv.conf ; echo 'nameserver 8.8.8.8' >> /etc/resolv.conf ; chattr +i /etc/resolv.conf" >NUL 2>&1

REM ## Loop until we get a successful repo update
:APTRELY
IF EXIST apterr DEL apterr
START /MIN /WAIT "apt-get update" %GO% "apt-get update 2> apterr"
FOR /F %%A in ("apterr") do If %%~zA NEQ 0 GOTO APTRELY

ECHO:
ECHO [%TIME:~0,8%] Prepare Distro                          (ETA: 1m30s)
%GO% "cd D:a/kalix12 ; dpkg --purge --force-all locales-all ; DEBIAN_FRONTEND=noninteractive apt-get download kali-archive-keyring libc-bin libc-l10n libc6 libpam0g locales-all libcrypt1 libgcc-s1 libstdc++6 libpam-runtime libpam-modules-bin libpam-modules gcc-14-base libzstd1 ; DEBIAN_FRONTEND=noninteractive dpkg -i --force-all ./*.deb 2> /dev/null; rm ./*.deb ; DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install git gnupg2 libc-ares2 libssh2-1 libaria2-0 aria2 acl pciutils ; echo 'exit 0' > /usr/bin/lspci ; echo 'exit 0' > /usr/bin/setfacl ; rm -rf %GITPRJ% ; echo 'Clone Git repo...' ; git clone --quiet -b %BRANCH% --depth=1 https://github.com/%GITORG%/%GITPRJ%.git ; chmod +x D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/* ; cp -p D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/systemd-sysusers /usr/local/bin ; apt-get -fy install systemd --no-install-recommends ; cp -p D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/systemd-sysusers /usr/bin ; apt-get -fy install" > "%TEMP%\kalix12\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Prepare Distro.log" 2>&1 

%GO% "find /tmp -type d -exec chmod 755 {} \;"
%GO% "find D:a/kalix12/�kalix12 -type f -exec chmod 644 {} \;"
%GO% "chmod +x D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/* ; cp -p D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/apt-fast /usr/local/bin ; chmod 755 D:\a\kalix12\kalix12/kalix12/dist/etc/profile.d/kalix12.sh D:\a\kalix12\kalix12/kalix12/dist/etc/kalix12/startwm.sh D:\a\kalix12\kalix12/kalix12/dist/usr/bin/pm-is-supported D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/restartwsl D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/initwsl ; chmod -R 7700 D:\a\kalix12\kalix12/kalix12/dist/etc/skel/.local"

ECHO [%TIME:~0,8%] 'kali-linux-default' metapackage and kalix12  (ETA: 3m30s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y install --allow-downgrades D:\a\kalix12\kalix12/kalix12/deb/x*.deb D:\a\kalix12\kalix12/kalix12/deb/synaptic_0.90.2_amd64.deb D:\a\kalix12\kalix12/kalix12/deb/g*.deb D:\a\kalix12\kalix12/kalix12/deb/lib*.deb D:\a\kalix12\kalix12/kalix12/deb/multiarch-support_2.27-3ubuntu1_amd64.deb D:\a\kalix12\kalix12/kalix12/deb/fonts-cascadia-code_2102.03-1_all.deb D:\a\kalix12\kalix12/kalix12/deb/pulseaudio-module-kalix12*.deb libpulsedsp libspeexdsp1 pulseaudio pulseaudio-utils sysv-rc libxcb-damage0 x11-apps x11-session-utils x11-xserver-utils xserver-common xserver-xorg xserver-xorg-core xserver-xorg-legacy dialog distro-info-data dumb-init inetutils-syslogd xdg-utils avahi-daemon libnss-mdns binutils putty unzip zip unzip dbus-x11 samba-common-bin lhasa arj unace liblhasa0 apt-config-icons apt-config-icons-hidpi apt-config-icons-large apt-config-icons-large-hidpi libvte-2.91-0 libvte-2.91-common libdbus-glib-1-2 xbase-clients python3-psutil kali-linux-default moreutils libpython3.12-minimal libpython3.12-stdlib python3.12 python3.12-minimal --no-install-recommends" > "%TEMP%\kalix12\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% kalix12 and 'kali-linux-default' metapackage.log" 2>&1

ECHO [%TIME:~0,8%] Kali Xfce desktop environment           (ETA: 3m00s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y install xfce4-settings xfdesktop4 xfce4-session xfdesktop4-data xfce4 xfwm4 qt5ct lsb-release xfce4-datetime-plugin ristretto parole mousepad mate-calc-common xfce4-taskmanager mate-calc xfce4-screenshooter xfce4-clipman xfce4-clipman-plugin xfce4-cpugraph-plugin xfce4-whiskermenu-plugin xdg-user-dirs xdg-user-dirs-gtk kazam kali-menu kali-themes kali-debtags kali-wallpapers-2023 gstreamer1.0-gl gstreamer1.0-plugins-bad gstreamer1.0-plugins-bad-apps gstreamer1.0-plugins-base-apps gstreamer1.0-plugins-good gstreamer1.0-tools mesa-utils qterminal libqt5x11extras5 libqtermwidget5-1 qterminal qtermwidget5-data epiphany-browser pcscd gstreamer1.0-fdkaac libaribb24-0 libavcodec-extra libavcodec-extra60 libopencore-amrnb0 libopencore-amrwb0 libvo-amrwbenc0 --no-install-recommends ; update-rc.d pcscd remove" > "%TEMP%\kalix12\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Kali Xfce desktop environment.log" 2>&1

REM ## Additional items to install can go here...
ECHO [%TIME:~0,8%] Extras [Seamonkey, Zenmap, CRD]         (ETA: 1m30s)
%GO% "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B9C16F2667CA5C CCC158AFC1289A29 ; echo 'deb http://downloads.sourceforge.net/project/ubuntuzilla/mozilla/apt all main' > /etc/apt/sources.list.d/mozilla.list ; cp /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d/ubuntu.gpg ; apt-get update" >NUL 2>&1
%GO% "wget -q https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb -O D:\a\kalix12\kalix12/chrome-remote-desktop_current_amd64.deb ; DEBIAN_FRONTEND=noninteractive apt-fast -y install tilix atril engrampa seamonkey-mozilla-build nmap ncat ndiff D:\a\kalix12\kalix12/chrome-remote-desktop_current_amd64.deb D:\a\kalix12\kalix12/kalix12/deb/zenmap_*.deb" > "%TEMP%\kalix12\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Extras [Seamonkey, Zenmap, CRD].log" 2>&1
%GO% "update-alternatives --install /usr/bin/www-browser www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/seamonkey 100" >NUL 2>&1
%GO% "mv /usr/bin/pkexec /usr/bin/pkexec.orig ; echo gksudo -k -S -g \$1 > /usr/bin/pkexec ; chmod 755 /usr/bin/pkexec"
%GO% "which schtasks.exe" > "%TEMP%\SCHT.tmp" & set /p SCHT=<"%TEMP%\SCHT.tmp"
%GO% "sed -i 's#SCHT#%SCHT%#g' D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/restartwsl ; sed -i 's#DISTRO#%DISTRO%#g' D:\a\kalix12\kalix12/kalix12/dist/usr/local/bin/restartwsl"

IF %LINDPI% GEQ 288 ( %GO% "sed -i 's/HISCALE/3/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/HISCALE/3/g' /tmp/dist/etc/profile.d/kalix12.sh" )
IF %LINDPI% GEQ 240 ( %GO% "sed -i 's/QQQ/120/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/III/60/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml ; sed -i 's/PPP/40/g' D:\a\kalix12\kalix12/kalix12/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/HISCALE/2/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/HISCALE/2/g' /tmp/dist/etc/profile.d/kalix12.sh" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/Kali-Dark-HiDPI/Kali-Dark-xHiDPI/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml ; sed -i 's/QQQ/96/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/III/48/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml ; sed -i 's/PPP/32/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" )
IF %LINDPI% LSS 192 ( %GO% "sed -i 's/HISCALE/1/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/HISCALE/1/g' /tmp/dist/etc/profile.d/kalix12.sh ; sed -i 's/QQQ/%LINDPI%/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ; sed -i 's/III/%ICONS%/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml ; sed -i 's/PPP/%PANEL%/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" )
IF %LINDPI% LSS 120 ( %GO% "sed -i 's/Kali-Dark-HiDPI/Kali-Dark/g' /tmp/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )

%GO% "sed -i 's/\\h/%DISTRO%/g' D:\a\kalix12\kalix12/kalix12/dist/etc/skel/.bashrc"
%GO% "sed -i 's/#Port 22/Port %SSHPRT%/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/WSLINSTANCENAME/%DISTRO%/g' /tmp/dist/usr/local/bin/initwsl"
%GO% "sed -i 's/#enable-dbus=yes/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/#host-name=foo/host-name=%COMPUTERNAME%-%DISTRO%/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/use-ipv4=yes/use-ipv4=no/g' /etc/avahi/avahi-daemon.conf"
%GO% "cp /mnt/c/Windows/Fonts/*.ttf /usr/share/fonts/truetype ; ssh-keygen -A ; adduser kalix12 ssl-cert &> /dev/null" > NUL
%GO% "rm /usr/lib/systemd/system/dbus-org.freedesktop.login1.service /usr/share/dbus-1/system-services/org.freedesktop.login1.service /usr/share/polkit-1/actions/org.freedesktop.login1.policy ; rm /usr/share/dbus-1/services/org.freedesktop.systemd1.service /usr/share/dbus-1/system-services/org.freedesktop.systemd1.service /usr/share/dbus-1/system.d/org.freedesktop.systemd1.conf /usr/share/polkit-1/actions/org.freedesktop.systemd1.policy /usr/share/applications/gksu.desktop" > NUL 2>&1
%GO% "cp -Rp /tmp/dist/* / ; cp -Rp /tmp/dist/etc/skel/.* /root ; chmod +x /etc/init.d/kalix12 ; update-rc.d -f kalix12 defaults ; update-rc.d -f inetutils-syslogd enable S 2 3 4 5 ; update-rc.d -f ssh enable S 2 3 4 5 ; update-rc.d -f avahi-daemon enable S 2 3 4 5 ; apt-get clean ; cd D:a/kalix12" >NUL 2>&1
%GO% "setcap cap_net_raw+p /bin/ping"
%GO% "sed -i 's/port=3389/port=%RDPPRT%/g' /etc/kalix12/kalix12.ini"
%GO% "sed -i 's/thinclient_drives/.kalix12/g' /etc/kalix12/sesman.ini"

SET RUNEND=%date% @ %time:~0,5%
CD %DISTROFULL%
ECHO:
SET /p XU=Create a NEW user in Kali for kalix12 GUI login. Enter username: 
POWERSHELL -Command $prd = read-host "Enter password for %XU%" -AsSecureString ; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($prd) ; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) > .tmp & set /p PWO=<.tmp
%GO% "useradd -m -p nulltemp -s /bin/bash %XU%"
%GO% "(echo '%XU%:%PWO%') | chpasswd"
%GO% "echo '%XU% ALL=(ALL:ALL) ALL' >> /etc/sudoers"
%GO% "sed -i 's/PLACEHOLDER/%XU%/g' /tmp/kalix12.rdp"
%GO% "sed -i 's/COMPY/LocalHost/g' /tmp/kalix12.rdp"
%GO% "sed -i 's/RDPPRT/%RDPPRT%/g' /tmp/kalix12.rdp"
%GO% "cp D:\a\kalix12\kalix12/kalix12/kalix12.rdp ./kalix12._"
ECHO $prd = Get-Content .tmp > .tmp.ps1
ECHO ($prd ^| ConvertTo-SecureString -AsPlainText -Force) ^| ConvertFrom-SecureString ^| Out-File .tmp  >> .tmp.ps1
POWERSHELL -ExecutionPolicy Bypass -Command ./.tmp.ps1
TYPE .tmp>.tmpsec.txt
COPY /y /b kalix12._+.tmpsec.txt "%DISTROFULL%\kalix12 (%XU%).rdp" > NUL
DEL /Q  kalix12._ .tmp*.* > NUL
ECHO:
ECHO Open Windows Firewall Ports for kalix12, SSH, mDNS...
NETSH AdvFirewall Firewall add rule name="%DISTRO% kalix12" dir=in action=allow protocol=TCP localport=%RDPPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Secure Shell" dir=in action=allow protocol=TCP localport=%SSHPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Avahi Daemon" dir=in action=allow protocol=UDP localport=5353,53791 > NUL
START /MIN "%DISTRO% Init" WSL ~ -u root -d %DISTRO% -e initwsl 2
ECHO Building RDP Connection file, Init system...
ECHO Set OW = GetObject(^"winmgmts:^" ^& ^"^{impersonationLevel^=impersonate^}!\\.\root\cimv2^") > "%LOCALAPPDATA%\kalix12.vbs"
ECHO Set ST = OW.Get(^"Win32_ProcessStartup^") >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO Set OC = ST.SpawnInstance_ >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO OC.ShowWindow ^= 0 >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO Set OP = GetObject(^"winmgmts:root\cimv2:Win32_Process^") >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO WScript.Sleep 2000 >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO RT = OP.Create( ^"WSLCONFIG.EXE /t kali-linux^", null, OC, intProcessID) >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO WScript.Sleep 5000 >> "%LOCALAPPDATA%\kalix12.vbs"
ECHO RT = OP.Create( ^"WSL.EXE ~ -u root -d kali-linux -e initwsl 2^", null, OC, intProcessID) >> "%LOCALAPPDATA%\kalix12.vbs"
POWERSHELL -Command "Copy-Item '%DISTROFULL%\kalix12 (%XU%).rdp' ([Environment]::GetFolderPath('Desktop'))"
ECHO Building Scheduled Task...
%GO% "cp D:\a\kalix12\kalix12/kalix12/kalix12.xml ."
%TEMP%\LxRunOffline.exe su -n %DISTRO% -v 1000
POWERSHELL -C "$WAI = (whoami)                       ; (Get-Content .\kalix12.xml).replace('AAAA', $WAI) | Set-Content .\kalix12.xml"
POWERSHELL -C "$WAC = '%LOCALAPPDATA%\kalix12.vbs' ; (Get-Content .\kalix12.xml).replace('QQQQ', $WAC) | Set-Content .\kalix12.xml"
SCHTASKS /Create /TN:%DISTRO% /XML ./kalix12.xml /F
PING -n 6 LOCALHOST > NUL
ECHO:
ECHO:      Start: %RUNSTART%
ECHO:        End: %RUNEND%
%GO%  "echo -ne '   Packages:'\   ; dpkg-query -l | grep "^ii" | wc -l "
ECHO:
ECHO:     * kalix12 Server listening on port %RDPPRT% and SSHd on port %SSHPRT%.
ECHO:
ECHO:     * Connection file for kalix12 session has been placed on your desktop.
ECHO:
ECHO:     * Launch or Relaunch kalix12 from Task Scheduler with the following command:
ECHO:       schtasks.exe /run /tn %DISTRO%
ECHO:
ECHO:     * Kill kalix12 with the following command:
ECHO        wslconfig.exe /t %DISTRO%
ECHO:
ECHO:     * This is a minimal installation of Kali. To install default packages:
ECHO:       sudo apt install kali-linux-default
ECHO:
ECHO:Installation of kalix12 (%DISTRO%) complete.
áECHO:Remote Desktop session will start shortly...
PING -n 6 LOCALHOST > NUL
START "Remote Desktop Connection" "MSTSC.EXE" "/V" "kalix12 (%XU%).rdp"
CD ..
ECHO:
:ENDSCRIPT
