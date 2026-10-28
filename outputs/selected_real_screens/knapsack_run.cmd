@echo off
mode con: cols=140 lines=40
title Dev-C++ / MinGW - Knapsack - 222024321062099
cd /d D:\new-bee\outputs\selected_real_screens
echo ============================================================
echo Dev-C++ compatible MinGW compilation and run - 0-1 Knapsack
echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile knapsack.cpp
echo g++ -std=c++11 -Wall -Wextra -O2 knapsack.cpp -o knapsack.exe
g++ -std=c++11 -Wall -Wextra -O2 knapsack.cpp -o knapsack.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS (exit code 0)
echo [2] Run knapsack.exe
echo ------------------------------------------------------------
knapsack.exe --compact < knapsack_input.txt
echo ------------------------------------------------------------
echo PROGRAM EXIT CODE: %errorlevel%
goto hold
:fail
echo BUILD FAILED (exit code %errorlevel%)
:hold
pause

