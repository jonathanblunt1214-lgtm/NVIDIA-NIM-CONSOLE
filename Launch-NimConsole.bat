@echo off
title NVIDIA-NIM-CONSOLE
mode con: cols=110 lines=35
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NimConsole.ps1"
