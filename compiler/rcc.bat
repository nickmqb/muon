@echo off
copy /y mu.exe mu_copy.exe >nul
mu_copy.exe --args mu.args --args msvc_debug.args --print_stats
if %errorlevel% neq 0 exit /b
copy /y mu.exe mu_copy.exe >nul
mu_copy.exe --args mu.args --args msvc_debug.args --print_stats
