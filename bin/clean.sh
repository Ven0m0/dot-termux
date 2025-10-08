#!/data/data/com.termux/files/usr/bin/env bash

LC_ALL=C

find /data/data/com.termux/files/home/.cache/ -type f -delete -print 2>/dev/null
find /data/data/com.termux/cache -type f -delete -print 2>/dev/null
find /data/data/com.termux/files/home/tmp/ -type f -delete -print 2>/dev/null
find /data/data/com.termux/files/home/ -type f -name "*.bak" -delete -print 2>/dev/null
find /data/data/com.termux/files/home -type f -name "*.log" -delete -print 2>/dev/null
