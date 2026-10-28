@echo off
title Dev-C++ / MinGW - Matrix Chain - 222024321062099
cd /d D:\new-bee\outputs\????_222024321062099
echo ============================================================
echo Dev-C++ compatible MinGW compilation and run
 echo Student: 222024321062099 Tan Shizhao - Software Engineering Class 4
echo ============================================================
echo [1] Compile matrix_chain.cpp
echo g++ -std=c++11 -Wall -Wextra -O2 matrix_chain.cpp -o matrix_chain.exe
g++ -std=c++11 -Wall -Wextra -O2 matrix_chain.cpp -o matrix_chain.exe
if errorlevel 1 goto fail
echo BUILD SUCCESS (exit code 0)
echo [2] Run matrix_chain.exe
echo ------------------------------------------------------------
matrix_chain.exe < input.txt
echo ------------------------------------------------------------
echo PROGRAM EXIT CODE: %errorlevel%
goto hold
:fail
echo BUILD FAILED (exit code %errorlevel%)
:hold
pause
