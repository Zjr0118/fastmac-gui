#configure.sh VNC_USER_PASSWORD VNC_PASSWORD

#disable spotlight indexing
sudo mdutil -i off -a

#Create new account
sudo dscl . -create /Users/vncuser
sudo dscl . -create /Users/vncuser UserShell /bin/bash
sudo dscl . -create /Users/vncuser RealName "VNC User"
sudo dscl . -create /Users/vncuser UniqueID 1001
sudo dscl . -create /Users/vncuser PrimaryGroupID 80
sudo dscl . -create /Users/vncuser NFSHomeDirectory /Users/vncuser
sudo dscl . -passwd /Users/vncuser $1
sudo dscl . -passwd /Users/vncuser $1
sudo createhomedir -c -u vncuser > /dev/null

#Enable VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes

#VNC password
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#Start VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# Prevent display sleep & auto-login
sudo pmset -a displaysleep 0 sleep 0
sudo pmset noidle &
caffeinate -d &
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "vncuser"
sudo caffeinate -u -t 15 &

# Best-effort: grant screen-recording permission to screen-sharing service
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "INSERT OR IGNORE INTO access (service, client, client_type, allowed, prompt_count) VALUES ('kTCCServiceScreenCapture','com.apple.screensharing.agent',1,1,0);" 2>/dev/null || echo "TCC.db blocked (SIP)"
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console 2>/dev/null || true
sleep 3

# Diagnose screenshot
sudo screencapture -x /tmp/screen.png 2>/dev/null
ls -la /tmp/screen.png 2>/dev/null

# ---- bore free TCP tunnel (download official binary) ----
ARCH=$(uname -m)
case "$ARCH" in
  arm64) BARCH="aarch64" ;;
  x86_64) BARCH="x86_64" ;;
  *) BARCH="x86_64" ;;
esac
BORE_URL=$(curl -s https://api.github.com/repos/ekzhang/bore/releases/latest | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for a in d.get('assets',[]):
        n=a['name']
        if 'apple-darwin' in n and '$BARCH' in n and n.endswith('.tar.gz'):
            print(a['browser_download_url']); break
except: pass
")
echo "bore url: $BORE_URL"
curl -sL "$BORE_URL" -o /tmp/bore.tar.gz && tar xzf /tmp/bore.tar.gz -C /tmp && sudo install -m755 /tmp/bore /usr/local/bin/bore
which bore && bore --version || echo "bore install failed"
nohup bore local 5900 --to bore.pub > /tmp/bore.log 2>&1 &
sleep 8
echo "=== bore tunnel output ==="
cat /tmp/bore.log
