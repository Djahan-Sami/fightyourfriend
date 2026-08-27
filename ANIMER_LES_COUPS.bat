@echo off
setlocal
if exist "%~dp0CONFIG_LOCAL.bat" call "%~dp0CONFIG_LOCAL.bat"
set "STUDIO=%~dp002_ATELIER_ANIMATIONS\RagdollBrawl_Animation.blend"
set "TOOLS=%~dp002_ATELIER_ANIMATIONS\ragdoll_brawl_tools.py"

if defined BLENDER if exist "%BLENDER%" goto launch
for %%B in (blender.exe) do (
  where %%B >nul 2>nul && set "BLENDER=%%B" && goto launch
)

echo Blender est introuvable.
echo Copie CONFIG_LOCAL.bat.example en CONFIG_LOCAL.bat,
echo puis indique le chemin de Blender dans ce fichier.
pause
exit /b 1

:launch
start "Ragdoll Brawl - Atelier" "%BLENDER%" "%STUDIO%" --python "%TOOLS%"
endlocal
