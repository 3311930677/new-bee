@echo off
mode con: cols=140 lines=40
title Dev-C++ / MinGW - Selected Experiments Verification - 222024321062099
cd /d D:\new-bee\outputs\selected_real_screens
echo ============================================================
echo Verification for the three selected experiments
echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile matrix_chain.cpp, lcs.cpp, knapsack.cpp
g++ -std=c++11 -Wall -Wextra -O2 matrix_chain.cpp -o matrix_chain.exe
if errorlevel 1 goto fail
g++ -std=c++11 -Wall -Wextra -O2 lcs.cpp -o lcs.exe
if errorlevel 1 goto fail
g++ -std=c++11 -Wall -Wextra -O2 knapsack.cpp -o knapsack.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS (three selected programs)
echo [2] Run selected samples and check outputs
echo ------------------------------------------------------------
matrix_chain.exe --compact < matrix_input.txt | findstr /C:"Minimum scalar multiplications: 15125" > nul
if errorlevel 1 goto fail
echo MATRIX CHAIN: PASS (15125)
lcs.exe --compact < lcs_input.txt | findstr /C:"LCS length: 4" > nul
if errorlevel 1 goto fail
echo LCS: PASS (length 4)
knapsack.exe --compact < knapsack_input.txt | findstr /C:"Maximum value: 15" > nul
if errorlevel 1 goto fail
echo 0-1 KNAPSACK: PASS (value 15)
echo TOTAL: 3/3 PASS
echo PROGRAM EXIT CODE: 0
goto hold
:fail
echo CHECK FAILED (exit code %errorlevel%)
:hold
pause
