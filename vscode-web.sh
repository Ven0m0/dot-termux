#!/data/data/com.termux/files/usr/bin/bash 

pkg i nodejs-lts build-essential python3
npm y -g code-server
code-server --auth none
