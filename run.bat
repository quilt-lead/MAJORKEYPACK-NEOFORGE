@echo off
cd /d "%~dp0"
setlocal

java @user_jvm_args.txt "@libraries/net/neoforged/neoforge/21.1.250/win_args.txt" %*

endlocal
