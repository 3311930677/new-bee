@echo off
mode con: cols=140 lines=40
title Dev-C++ / MinGW - Verification - 222024321062099
cd /d D:\new-bee\outputs\selected_real_screens
echo ============================================================
echo Dev-C++ compatible MinGW compilation and verification
 echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile dp_lab_ide.cpp
echo g++ -std=c++11 -Wall -Wextra -O2 dp_lab_ide.cpp -o dp_lab_ide.exe
g++ -std=c++11 -Wall -Wextra -O2 dp_lab_ide.cpp -o dp_lab_ide.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS (exit code 0)
echo [2] Run random and boundary checks
echo ------------------------------------------------------------
dp_lab_ide.exe 5
dp_lab_ide.exe 6
echo ------------------------------------------------------------
echo PROGRAM EXIT CODE: %errorlevel%
goto hold
:fail
echo BUILD FAILED (exit code %errorlevel%)
:hold
pause
