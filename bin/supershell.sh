#!/bin/sh
#
timeout 4 echo "
	#---Please approve logcat access for SuperShell---#
	#--- to extract the 'adb connect' IP & port values---#
	"
set -x
# Make sure our ADB environment is clean
adb kill-server
adb usb

# Get the IP and port number for the 'adb connect' command
# Port number first... 

timeout 3 logcat | grep -e "adbwifi" -e "adb wifi" > ~/adbport.txt
ADB_PORT_VALUE=$(tail -n 1 ~/adbport.txt | awk '{print substr($NF, length($NF)-4)}')
export ADB_PORT=$ADB_PORT_VALUE

#... Then IP address 

ifconfig | grep -o '\b192\.168\.[0-9]\+\.[0-9]\+\b' | grep -v '255' > ~/adbip.txt && chmod 777 ~/adbip.txt
index=1
while read ip; do
    eval ADB${index}="${ip}:${ADB_PORT}"
    ((index++))
done < ~/adbip.txt
i=1
while [ $i -lt $index ]; do
    var_name="ADB${i}"
    adb_address=$(eval echo \$$var_name)  # Retrieve the value of ADB1, ADB2, etc.
    adb_ip=$(echo $adb_address | cut -d: -f1)  # Extract the IP address part (before the colon)
    echo $adb_address
    echo adb_ip
# Now we try to connect 
    
    if timeout 5 adb connect "$adb_address" | grep -q 'connected'; then
        echo "Connected to $adb_address"
        export adb_address  # Export the full address (IP:PORT)
        export adb_ip       # Export only the IP address
        break
    fi
    ((i++))
done

# Step 3: Execute emulator commands
adb reverse localabstract:$ADB_PORT tcp:5555
adb connect $adb_address
adb reverse localabstract:$ADB_PORT tcp:5555
adb tcpip 5555
adb devices
adb connect $adb_ip:5555
if adb devices | grep -q emulator; then
    echo "
    #---- Mobile ADB Shell Enabled ----#
 "
fi

# Delete text files created by the script & pop that shell! 
rm -rf ~/adbip.txt
rm -rf ~/adbport.txt
adb shell
