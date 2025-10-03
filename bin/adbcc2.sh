#!/bin/bash

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Pre-run Checks ---

# Function to check for required dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking for required tools (adb, ffmpeg, imagemagick)...${NC}"
    local missing_deps=0
    for tool in adb ffmpeg convert; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}Error: '$tool' is not installed. Please install it to continue.${NC}"
            missing_deps=$((missing_deps + 1))
        fi
    done

    if [ "$missing_deps" -ne 0 ]; then
        echo -e "${RED}Aborting due to missing dependencies.${NC}"
        exit 1
    fi
    echo -e "${GREEN}All required tools are present.${NC}"
}

# Function to check for a connected and authorized ADB device
check_device() {
    echo -e "${YELLOW}Looking for a connected Android device...${NC}"
    local device_state
    device_state=$(adb get-state 2>/dev/null)

    if [ "$device_state" != "device" ]; then
        echo -e "${RED}Error: No device found or device not authorized.${NC}"
        echo -e "${YELLOW}Please ensure your device is connected, USB debugging is enabled, and you have authorized the connection.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Device found and connected successfully.${NC}"
}


# --- Cleaning Functions ---

# Function to clean log files and buffers
clean_logs() {
    echo -e "\n${YELLOW}--- Cleaning Android Logs ---${NC}"
    echo "Clearing logcat buffer..."
    adb shell logcat -c
    echo "Removing log files from /cache/log..."
    adb shell rm -rf /cache/log/*
    echo "Removing log files from /data/log..."
    adb shell rm -rf /data/log/*
    echo "Removing tombstones..."
    adb shell rm -rf /data/tombstones/*
    echo -e "${GREEN}Log cleaning complete.${NC}"
}

# Function to clear application cache
clean_cache() {
    echo -e "\n${YELLOW}--- Cleaning Application Caches ---${NC}"
    echo "Sending command to trim all cached data. This may take a moment..."
    # Using a very large value to ask the system to clear as much as possible
    adb shell pm trim-caches 999999999M
    echo -e "${GREEN}Cache cleaning command sent successfully.${NC}"
}

# Function to optimize WhatsApp media
optimize_whatsapp() {
    echo -e "\n${YELLOW}--- Optimizing WhatsApp Media ---${NC}"
    
    # Find the correct WhatsApp media path
    local remote_dir=""
    if adb shell ls "/sdcard/Android/media/com.whatsapp/WhatsApp/Media" &>/dev/null; then
        remote_dir="/sdcard/Android/media/com.whatsapp/WhatsApp/Media"
    elif adb shell ls "/sdcard/WhatsApp/Media" &>/dev/null; then
        remote_dir="/sdcard/WhatsApp/Media"
    else
        echo -e "${RED}Error: Could not find WhatsApp media directory on the device.${NC}"
        return 1
    fi

    local local_dir="optimized_whatsapp_media"
    echo "Media will be pulled from: ${remote_dir}"
    echo "Optimized files will be saved to: ./${local_dir}"
    
    mkdir -p "$local_dir"
    
    echo -e "\n${YELLOW}Pulling media from the device. This could take a very long time depending on the amount of media...${NC}"
    adb pull "$remote_dir" "$local_dir"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to pull media from the device. Aborting optimization.${NC}"
        return 1
    fi
    
    local pulled_data_path="$local_dir/Media"
    
    echo -e "\nCalculating original size..."
    local original_size
    original_size=$(du -sh "$pulled_data_path")
    
    echo -e "\n${YELLOW}Optimizing images (JPG, PNG)...${NC}"
    find "$pulled_data_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | while IFS= read -r -d '\0' file; do
        echo "Processing: $file"
        # Using mogrify to overwrite the pulled files with optimized versions
        mogrify -quality 85 "$file"
    done

    echo -e "\n${YELLOW}Optimizing videos (MP4). This is CPU intensive and will take time...${NC}"
    find "$pulled_data_path" -type f -iname "*.mp4" -print0 | while IFS= read -r -d '\0' file; do
        echo "Processing: $file"
        local temp_file
        temp_file="${file}.tmp.mp4"
        # Re-encode video with H.265 codec for better compression
        ffmpeg -i "$file" -vcodec libx265 -crf 28 "$temp_file" -y &>/dev/null && mv "$temp_file" "$file"
    done
    
    echo -e "\n--- Optimization Complete ---"
    echo -e "Original size:  ${YELLOW}$original_size${NC}"
    echo -e "Optimized size: ${GREEN}$optimized_size${NC}"
    echo -e "\n${YELLOW}IMPORTANT: The optimized files are located in the '${local_dir}' directory on your computer."
    echo -e "No files on your Android device have been changed or deleted.${NC}"
}

# --- Main Menu ---

main_menu() {
    while true; do
        echo -e "\n--- Android Deep Cleaner ---"
        echo "1) Clean Logs"
        echo "2) Clean Caches"
        echo "3) Optimize WhatsApp Media (Safe Mode)"
        echo "4) Run All Cleaning Tasks"
        echo "q) Quit"
        echo "--------------------------"
        read -rp "Enter your choice: " choice
        
        case $choice in
            1)
                clean_logs
                ;;
            2)
                clean_cache
                ;;
            3)
                optimize_whatsapp
                ;;
            4)
                clean_logs
                clean_cache
                optimize_whatsapp
                ;;
            q|Q)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
}

# --- Script Execution ---

# Run pre-run checks first
check_dependencies
check_device

# Show the main menu
main_menu
