@echo off
title NVIDIA NIM Agentic Console
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NimConsole.ps1"
pause