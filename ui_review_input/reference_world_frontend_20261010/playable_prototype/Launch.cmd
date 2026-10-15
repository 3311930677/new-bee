@echo off
setlocal
rem A quoted path ending in a backslash escapes its closing quote for Godot.
rem The final dot keeps the project path valid when passed to the executable.
for %%I in ("%~dp0..\..\..") do set "TASK_ROOT=%%~fI"
set "ENGINE_EXE=%TASK_ROOT%\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "APPDATA=%~dp0runtime"
if not exist "%ENGINE_EXE%" (
  echo Godot executable was not found:
  echo %ENGINE_EXE%
  pause
  exit /b 1
)
if not exist "%~dp0project.godot" (
  echo The prototype project.godot is missing.
  pause
  exit /b 1
)
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%ENGINE_EXE%" --path "%~dp0." --rendering-method gl_compatibility --audio-driver Dummy %* >"%~dp0launch.stdout" 2>"%~dp0launch.stderr"
set "LAUNCH_RESULT=%ERRORLEVEL%"
if not "%LAUNCH_RESULT%"=="0" (
  echo The prototype could not start. Details:
  type "%~dp0launch.stderr"
  echo Log: %~dp0launch.stdout
  pause
)
exit /b %LAUNCH_RESULT%
