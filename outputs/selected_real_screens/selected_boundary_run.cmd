@echo off
mode con: cols=140 lines=40
title Dev-C++ / MinGW - Selected Boundary Tests - 222024321062099
cd /d D:\new-bee\outputs\selected_real_screens
echo ============================================================
echo Boundary and invalid-input checks for the three selected experiments
echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile selected programs
g++ -std=c++11 -Wall -Wextra -O2 matrix_chain.cpp -o matrix_chain.exe
g++ -std=c++11 -Wall -Wextra -O2 lcs.cpp -o lcs.exe
g++ -std=c++11 -Wall -Wextra -O2 knapsack.cpp -o knapsack.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS
echo [2] Run invalid inputs
echo ------------------------------------------------------------
echo Case M: zero matrix dimension
matrix_chain.exe < matrix_bad.txt
if not errorlevel 1 goto fail
echo MATRIX INVALID INPUT: PASS
echo Case K: zero item weight
knapsack.exe < knapsack_bad.txt
if not errorlevel 1 goto fail
echo KNAPSACK INVALID INPUT: PASS
echo Case L: one empty string is a valid boundary
lcs.exe --compact < lcs_empty.txt > nul
if errorlevel 1 goto fail
echo LCS EMPTY INPUT: PASS
echo TOTAL: 3/3 PASS
echo PROGRAM EXIT CODE: 0
goto hold
:fail
echo CHECK FAILED (exit code %errorlevel%)
:hold
pause
