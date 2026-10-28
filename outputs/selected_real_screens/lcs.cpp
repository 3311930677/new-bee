#include <algorithm>
#include <iostream>
#include <string>
#include <vector>
using namespace std;

int main(int argc, char** argv) {
    string x, y;
    cout << "Longest Common Subsequence (Dynamic Programming)\n";
    cout << "Input two strings (press Enter for the sample):\n";
    if (!getline(cin, x)) { x = "ABCBDAB"; y = "BDCABA"; }
    else if (!getline(cin, y)) y = "";
    if (x.empty() && y.empty()) { x = "ABCBDAB"; y = "BDCABA"; }
    if (x.size() > 2000 || y.size() > 2000) {
        cerr << "ERROR: strings must be at most 2000 characters\n"; return 1;
    }
    int m = static_cast<int>(x.size()), n = static_cast<int>(y.size());
    vector<vector<int>> dp(m + 1, vector<int>(n + 1, 0));
    bool compact = argc > 1 && string(argv[1]) == "--compact";
    cout << "X=" << x << ", Y=" << y << "\n";
    cout << "State: L[i][j] = LCS length of X[1..i], Y[1..j]\n";
    for (int i = 1; i <= m; ++i) {
        for (int j = 1; j <= n; ++j) {
            if (x[i - 1] == y[j - 1]) dp[i][j] = dp[i - 1][j - 1] + 1;
            else dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
            if (!compact) cout << "L[" << i << "][" << j << "]=" << dp[i][j] << ' ';
        }
        if (!compact) cout << "\n";
    }
    string seq;
    int i = m, j = n;
    cout << "Backtracking from (" << m << "," << n << "):\n";
    int steps = 0;
    while (i > 0 && j > 0) {
        ++steps;
        if (x[i - 1] == y[j - 1]) {
            seq += x[i - 1];
            if (!compact) cout << "(" << i << "," << j << ") MATCH " << x[i - 1] << " -> diagonal\n";
            --i; --j;
        } else if (dp[i - 1][j] >= dp[i][j - 1]) {
            if (!compact) cout << "(" << i << "," << j << ") UP\n";
            --i;
        } else {
            if (!compact) cout << "(" << i << "," << j << ") LEFT\n";
            --j;
        }
    }
    reverse(seq.begin(), seq.end());
    if (compact) cout << "Backtracking steps: " << steps << "; matches recovered and reversed.\n";
    cout << "LCS length: " << seq.size() << "\nLCS: " << seq << "\n";
    return 0;
}
