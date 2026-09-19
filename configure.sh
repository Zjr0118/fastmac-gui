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

# Diagnose: try to wake loginwindow into a GUI session
sudo launchctl bootstrap gui/$(id -u vncuser) 2>/dev/null || true
sleep 5

# Capture screen to diagnose black screen
sudo screencapture -x /tmp/screen.png 2>/dev/null
echo "=== SCREENSHOT ==="
ls -la /tmp/screen.png 2>/dev/null
# Report whether image is mostly black (file size + pixel info via sips)
sips -g pixelWidth -g pixelHeight /tmp/screen.png 2>/dev/null

# pinggy free TCP tunnel
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q 2>/dev/null || true
ssh -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -T -R0:localhost:5900 tcp@free.pinggy.io > /tmp/pinggy.log 2>&1 &
sleep 8
echo "=== Pinggy tunnel output ==="
cat /tmp/pinggy.log
