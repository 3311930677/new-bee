@echo off
title DP Lab - Matrix Chain - 222024321062099
cd /d D:\new-bee\outputs\dp_lab_222024321062099
echo ============================================================
echo Dynamic Programming Lab - REAL GCC TERMINAL
echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile command:
echo C:\Users\tsz\Downloads\MinGW\bin\g++.exe -std=c++17 -O2 src\dp_lab_ide.cpp -o evidence\native\dp_lab_native.exe
C:\Users\tsz\Downloads\MinGW\bin\g++.exe -std=c++17 -O2 src\dp_lab_ide.cpp -o evidence\native\dp_lab_native.exe
if errorlevel 1 goto fail
echo [2] BUILD SUCCESS - exit code 0
echo [3] Run: dp_lab_native.exe 1
echo ------------------------------------------------------------
evidence\native\dp_lab_native.exe 1
echo ------------------------------------------------------------
echo [4] PROGRAM EXIT CODE: %errorlevel%
goto done
:fail
echo BUILD FAILED - exit code %errorlevel%
:done
echo.
echo This is a real Windows console capture from the compiled program.
pause
