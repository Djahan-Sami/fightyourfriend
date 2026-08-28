@echo off
setlocal
if exist "%~dp0CONFIG_LOCAL.bat" call "%~dp0CONFIG_LOCAL.bat"

if defined GODOT if exist "%GODOT%" goto launch
for %%G in (godot.exe Godot_v4.7.2-stable_win64.exe Godot_v4.7.2-stable_win64_console.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto launch
)

echo Godot est introuvable.
echo Copie CONFIG_LOCAL.bat.example en CONFIG_LOCAL.bat,
echo puis indique le chemin de Godot dans ce fichier.
pause
exit /b 1

:launch
start "Fight Your Friend" "%GODOT%" --path "%~dp001_JEU"
endlocal
