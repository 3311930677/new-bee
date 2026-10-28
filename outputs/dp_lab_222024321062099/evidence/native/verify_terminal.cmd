@echo off
title DP Lab - Verification - 222024321062099
cd /d D:\new-bee\outputs\dp_lab_222024321062099
echo REAL GCC TERMINAL - VERIFICATION
echo [1] Run compiled program: dp_lab_native.exe 6
echo ------------------------------------------------------------
evidence\native\dp_lab_native.exe 6
echo ------------------------------------------------------------
echo PROGRAM EXIT CODE: %errorlevel%
pause
