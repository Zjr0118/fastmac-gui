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

# Prevent display sleep
sudo pmset -a displaysleep 0 sleep 0
sudo pmset noidle &
caffeinate -d &
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "vncuser"
sudo caffeinate -u -t 15 &

# ---- Virtual display via BetterDisplay (fix headless VNC black screen) ----
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_CASK_OPTS="--no-quarantine"
if command -v brew >/dev/null 2>&1; then
  brew install --cask betterdisplay 2>&1 | tail -5 || echo "betterdisplay cask install failed"
else
  echo "brew not found"
fi
open -a "BetterDisplay" 2>/dev/null || echo "BetterDisplay app not found"
sleep 8
open "betterdisplay://create?name=VNC&width=1920&height=1080" 2>/dev/null || true
sleep 5

# Best-effort screen-recording permission
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "INSERT OR IGNORE INTO access (service, client, client_type, allowed, prompt_count) VALUES ('kTCCServiceScreenCapture','com.apple.screensharing.agent',1,1,0);" 2>/dev/null || echo "TCC.db write blocked (SIP)"
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console 2>/dev/null || true
sleep 5

# Diagnose screenshot
sudo screencapture -x /tmp/screen.png 2>/dev/null
ls -la /tmp/screen.png 2>/dev/null

# ---- bore free TCP tunnel (replaces pinggy) ----
export HOMEBREW_NO_AUTO_UPDATE=1
brew install bore 2>/dev/null || brew install ekzhang/tap/bore 2>/dev/null || echo "bore brew install failed"
which bore && bore --version || echo "bore not on PATH"
nohup bore local 5900 --to bore.pub > /tmp/bore.log 2>&1 &
sleep 8
echo "=== bore tunnel output ==="
cat /tmp/bore.log
