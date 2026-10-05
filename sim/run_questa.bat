@echo off
setlocal
cd /d "%~dp0\.."
vsim -c -do sim/run_questa.do
endlocal
