#!/data/data/com.termux/files/usr/bin/bash


#  vscode server
pkg i nodejs-lts build-essential python3
npm i -g code-server
code-server --auth none
