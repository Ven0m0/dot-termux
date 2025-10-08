

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
```
```sh
adb shell cmd netpolicy set restrict-background true
```
```sh
adb shell cmd content_capture destroy sessions
```
