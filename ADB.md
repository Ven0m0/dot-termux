```sh
adb shell cmd package compile -p PRIORITY_INTERACTIVE_FAST --force-merge-profile --full -a -r cmdline -m speed
```

```sh
adb shell cmd package compile -p PRIORITY_INTERACTIVE_FAST --force-merge-profile --full -a -r cmdline -m speed-profile -f
```

```sh
adb shell am broadcast -a android.intent.action.ACTION_OPTIMIZE_DEVICE
```

```
adb shell am broadcast -a com.android.systemui.action.CLEAR_MEMORY
```

```sh
adb shell am kill-all
```

```sh
adb shell cmd activity kill-all
```

```sh
adb shell pm bg-dexopt-job
```

```sh
adb shell cmd stats clear-puller-cache
```

```sh
adb shell cmd wifi set-verbose-logging disabled
```

```sh
adb shell cmd voiceinteraction set-debug-hotword-logging false
```

```sh
adb shell cmd looper_stats disable
```

```sh
adb shell cmd display ab-logging-disable
```

```sh
adb shell cmd display dwb-logging-disable
```

```sh
adb shell cmd activity idle-maintenance
adb shell sm idle-maint run
```

```sh
adb shell cmd netpolicy set restrict-background true
```

```sh
adb shell cmd content_capture destroy sessions
```

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

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
adb-connect() {
    if [ -z "$1" ]; then
        echo "Usage: adb-connect <device-ip>"
        return 1
    fi
    adb connect $1:5555
}

# Function to start SSH server
ssh-start() {
    sshd
    echo "SSH server started on port 8022"
    echo "Connect using: ssh -p 8022 $(whoami)@<device-ip>"
}

# Function to stop SSH server
ssh-stop() {
    pkill sshd
    echo "SSH server stopped"
}
```

```bash
pkg up -y; pkg upgrade -y
pkg i -y jpegoptim optipng libwebp fd gifsicle parallel
```
```bash
fd -e jpg -e jpeg -x jpegoptim -s --auto-mode -m85
```
```bash
fd -e png -x optipng -o2 -strip all -fix -clobber
```
```bash
fd -e jpg -e png -x sh -c 'cwebp -q 80 "$1" -o "${1%.*}.webp" && rm "$1"' _ {}
```
