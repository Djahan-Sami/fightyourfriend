@echo off
setlocal
if exist "%~dp0CONFIG_LOCAL.bat" call "%~dp0CONFIG_LOCAL.bat"

if defined GODOT if exist "%GODOT%" goto export
for %%G in (godot.exe Godot_v4.7.2-stable_win64.exe Godot_v4.7.2-stable_win64_console.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto export
)

echo Godot est introuvable.
echo Copie CONFIG_LOCAL.bat.example en CONFIG_LOCAL.bat,
echo puis indique le chemin de Godot dans ce fichier.
pause
exit /b 1

:export
if not exist "%~dp0build" mkdir "%~dp0build"
"%GODOT%" --headless --path "%~dp001_JEU" --export-release "Windows" "%~dp0build\FightYourFriend.exe"
if errorlevel 1 (
  echo.
  echo L'export a echoue. Verifie que les modeles d'exportation Godot 4.7.2 sont installes.
  pause
  exit /b 1
)
echo.
echo Version Windows creee dans le dossier build.
pause
endlocal
