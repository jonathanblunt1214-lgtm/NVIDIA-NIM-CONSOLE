@echo off
title "NVIDIA NIM Console & Auto-Sync"
cd /d "%~dp0"

:: 1. Launch silent background sync daemon (15 min interval)
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0SyncDaemon.ps1"

:: 2. Launch interactive console with session persistence
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NimConsole.ps1"

pause
