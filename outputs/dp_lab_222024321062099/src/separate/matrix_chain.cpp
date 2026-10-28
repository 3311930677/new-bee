#include <algorithm>
#include <functional>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
using ll = long long;

int main() {
    int n;
    cout << "Matrix Chain Multiplication (Dynamic Programming)\n";
    cout << "Input n and dimensions p[0..n] (press Enter for the sample):\n";
    string line;
    getline(cin, line);
    vector<int> p;
    if (line.empty()) {
        p = {30, 35, 15, 5, 10, 20, 25};
    } else {
        istringstream header(line);
        if (!(header >> n) || n < 1 || n > 100) {
            cerr << "ERROR: matrix count must be in 1..100\n"; return 1;
        }
        p.resize(n + 1);
        for (int &x : p) {
            if (!(header >> x) && !(cin >> x)) {
                cerr << "ERROR: missing dimension\n"; return 1;
            }
            if (x < 1 || x > 100000) {
                cerr << "ERROR: dimensions must be in 1..100000\n"; return 1;
            }
        }
    }
    n = static_cast<int>(p.size()) - 1;
    const ll INF = numeric_limits<ll>::max() / 4;
    vector<vector<ll>> dp(n, vector<ll>(n, 0));
    vector<vector<int>> split(n, vector<int>(n, -1));
    cout << "Input dimensions: ";
    for (int x : p) cout << x << ' ';
    cout << "\nState: M[i][j] = minimum scalar multiplications for Ai..Aj\n";
    for (int len = 2; len <= n; ++len) {
        for (int i = 0; i + len <= n; ++i) {
            int j = i + len - 1;
            dp[i][j] = INF;
            cout << "M[" << i + 1 << "][" << j + 1 << "]: ";
            for (int k = i; k < j; ++k) {
                ll candidate = dp[i][k] + dp[k + 1][j]
                    + 1LL * p[i] * p[k + 1] * p[j + 1];
                cout << "k=" << k + 1 << " -> " << candidate << "  ";
                if (candidate < dp[i][j]) {
                    dp[i][j] = candidate;
                    split[i][j] = k;
                }
            }
            cout << "choose " << dp[i][j] << "\n";
        }
    }
    function<string(int,int)> order = [&](int i, int j) -> string {
        if (i == j) return "A" + to_string(i + 1);
        int k = split[i][j];
        return "(" + order(i, k) + " x " + order(k + 1, j) + ")";
    };
    cout << "Minimum scalar multiplications: " << dp[0][n - 1] << "\n";
    cout << "Optimal order: " << order(0, n - 1) << "\n";
    return 0;
}

