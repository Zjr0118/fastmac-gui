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

# ---- Enable OpenSSH remote login ----
sudo systemsetup -setremotelogin on 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
echo "SSH status: $(sudo systemsetup -getremotelogin 2>/dev/null)"

#Enable VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes

#VNC password
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#Start VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# Prevent display sleep
sudo pmset -a displaysleep 0 sleep 0
sudo pmset noidle &
caffeinate -d &

# ---- bore binary install ----
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
curl -sL "$BORE_URL" -o /tmp/bore.tar.gz && tar xzf /tmp/bore.tar.gz -C /tmp && sudo install -m755 /tmp/bore /usr/local/bin/bore

# bore tunnel: VNC + SSH
nohup bore local 5900 --to bore.pub > /tmp/bore_vnc.log 2>&1 < /dev/null &
nohup bore local 22 --to bore.pub > /tmp/bore_ssh.log 2>&1 < /dev/null &
sleep 8
echo "=== VNC tunnel ==="; cat /tmp/bore_vnc.log
echo "=== SSH tunnel ==="; cat /tmp/bore_ssh.log
