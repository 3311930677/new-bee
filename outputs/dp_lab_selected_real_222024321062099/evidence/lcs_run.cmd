@echo off
mode con: cols=140 lines=40
title Dev-C++ / MinGW - LCS - 222024321062099
cd /d D:\new-bee\outputs\selected_real_screens
echo ============================================================
echo Dev-C++ compatible MinGW compilation and run - LCS
echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile lcs.cpp
echo g++ -std=c++11 -Wall -Wextra -O2 lcs.cpp -o lcs.exe
g++ -std=c++11 -Wall -Wextra -O2 lcs.cpp -o lcs.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS (exit code 0)
echo [2] Run lcs.exe
echo ------------------------------------------------------------
lcs.exe --compact < lcs_input.txt
echo ------------------------------------------------------------
echo PROGRAM EXIT CODE: %errorlevel%
goto hold
:fail
echo BUILD FAILED (exit code %errorlevel%)
:hold
pause

