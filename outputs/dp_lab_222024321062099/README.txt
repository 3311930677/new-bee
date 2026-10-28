动态规划实验材料
学号：222024321062099
姓名：谈世钊
班级：软工中外4班

文件说明
222024321062099谈世钊.docx：实验报告，含四个问题的分析、伪代码、关键代码、截图和总结。
src/dp_lab.cpp：完整 C++17 源码，包含四类算法和独立穷举校验。
dp_lab.exe：由本机 MinGW GCC 13.2.0 编译的 Windows 可执行程序。
evidence/*_input.txt：实际测试输入。
evidence/*_output.txt：程序实际标准输出。
evidence/*.png：运行日志查看页的浏览器截图，并非终端界面截图。
evidence/*.html：截图对应的本地日志查看页。
evidence/records.json：运行记录，包括输入、输出和退出码。
evidence/environment.json：编译环境、随机种子、源码 SHA-256。
run_experiments.py：使用 Python 标准库调用程序、保存日志并完成额外命令行检查。

编译（在解压目录中使用 PowerShell）
g++ -std=c++17 -O2 -Wall -Wextra -pedantic src/dp_lab.cpp -o dp_lab.exe

运行并手动输入数据
.\dp_lab.exe matrix
.\dp_lab.exe lcs
.\dp_lab.exe knapsack
.\dp_lab.exe equipment

运行固定种子的校验
.\dp_lab.exe verify

自动重跑典型算例与额外边界测试
python run_experiments.py

典型算例期望结果
矩阵连乘：15125；LCS：长度4，序列BCBA；背包：价值15，物品1、2、5；设备更新：成本255，周期2、2、2。
随机对照与内置检查：808/808 PASS；额外命令行检查：11/11 PASS。

提交前请自行核对算法和报告内容，并按照课程要求结合自己的理解修改心得。
