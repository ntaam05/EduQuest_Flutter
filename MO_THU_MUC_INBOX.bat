@echo off
if not exist "%~dp0backend\inbox" mkdir "%~dp0backend\inbox"
start "" explorer "%~dp0backend\inbox"
