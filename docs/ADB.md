```bash
adb shell cmd package compile -p PRIORITY_INTERACTIVE_FAST --force-merge-profile --full -a -r cmdline -m speed
```
```bash
adb shell cmd package compile -p PRIORITY_INTERACTIVE_FAST --force-merge-profile --full -a -r cmdline -m speed-profile -f
```
```bash
adb shell am broadcast -a android.intent.action.ACTION_OPTIMIZE_DEVICE
```
```
adb shell am broadcast -a com.android.systemui.action.CLEAR_MEMORY
```
```bash
adb shell am kill-all
```
```bash
adb shell cmd activity kill-all
```
```bash
adb shell pm bg-dexopt-job
```
```bash
adb shell cmd stats clear-puller-cache
```
```bash
adb shell cmd wifi set-verbose-logging disabled
```
```bash
adb shell cmd voiceinteraction set-debug-hotword-logging false
```
```bash
adb shell cmd looper_stats disable
```
```bash
adb shell cmd display ab-logging-disable
```
```bash
adb shell cmd display dwb-logging-disable
```
```bash
adb shell cmd activity idle-maintenance
adb shell sm idle-maint run
```
```bash
adb shell cmd netpolicy set restrict-background true
```
```bash
adb shell cmd content_capture destroy sessions
```
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo "SSH key generated at ~/.ssh/id_rsa"
fi
# ADB shortcuts
alias adbs='adb shell'
alias adbd='adb devices'
alias adbr='adb reboot'
alias adbw='adb tcpip 5555'
# Function to quickly connect to wireless ADB
adb-connect(){
  [[ -z "$1" ]] && { echo "Usage: adb-connect <ip>:<port>"; return 1; }
  adb connect "${1}:${2:-5555}"
}
# Function to start SSH server
ssh-start(){
  sshd
  echo "Connect using: ssh -p 8022 $(id -un)@<device-ip>"
}
# Function to stop SSH server
ssh-stop(){ pkill sshd && echo "SSH server stopped"; }
```
```bash
yes | pkg up -y; yes | pkg upgrade -y
```
