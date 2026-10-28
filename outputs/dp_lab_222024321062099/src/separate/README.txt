四个独立 C++ 程序（每个文件都有 main，可单独编译）

1. matrix_chain.cpp：矩阵连乘，输出候选代价、最优断开点和括号化方案。
2. lcs.cpp：最长公共子序列，输出 DP 表状态和回溯路径。
3. knapsack.cpp：0-1 背包，输出每阶段最优值和选取物品的回溯过程。
4. equipment.cpp：设备更新，输出周期成本、候选决策和最终更新计划。

运行方式：
- 每个文件可单独在 Dev-C++ 中打开，启用 C++11 或更高标准后编译运行。
- 对矩阵连乘、背包和设备更新，在第一个输入提示处直接回车使用报告中的样例。
- LCS 输入两行字符串；连续两次回车使用样例 ABCBDAB / BDCABA。
- 自定义输入样例见同目录下 *_input.txt，双击同名 exe 可运行。
- 生成的 exe 使用本机 MinGW GCC 编译，不需要其他实验源码或自定义头文件。

编译示例：
g++ -std=c++11 -Wall -Wextra -O2 matrix_chain.cpp -o matrix_chain.exe

矩阵连乘输入：第一行 n，接下来 n+1 个维度。
LCS 输入：两行字符串。
背包输入：第一行 n capacity，随后每行 weight value。
设备更新输入：第一行 years max_life price，第二行维护费用，第三行残值。
