#include <algorithm>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
using ll = long long;

int main() {
    int n, capacity;
    cout << "0-1 Knapsack (Dynamic Programming)\n";
    cout << "Input item_count and capacity (press Enter for the sample):\n";
    string line;
    getline(cin, line);
    bool sample = line.empty();
    if (sample) {
        n = 5; capacity = 10;
    } else {
        istringstream header(line);
        if (!(header >> n >> capacity) || n < 0 || n > 500 || capacity < 0 || capacity > 10000) {
            cerr << "ERROR: invalid item count or capacity\n"; return 1;
        }
    }
    vector<int> w(n);
    vector<ll> v(n);
    if (sample) {
        w = {2, 2, 6, 5, 4}; v = {6, 3, 5, 4, 6};
    } else {
        for (int i = 0; i < n; ++i) {
            if (!(cin >> w[i] >> v[i]) || w[i] <= 0 || v[i] < 0 || v[i] > 1000000000) {
                cerr << "ERROR: invalid item weight or value\n"; return 1;
            }
        }
    }
    vector<vector<ll>> dp(n + 1, vector<ll>(capacity + 1, 0));
    cout << "Capacity=" << capacity << "\nWeights: ";
    for (int x : w) cout << x << ' ';
    cout << "\nValues : ";
    for (ll x : v) cout << x << ' ';
    cout << "\nState: B[i][c] = best value using first i items and capacity c\n";
    for (int i = 1; i <= n; ++i) {
        for (int c = 0; c <= capacity; ++c) {
            dp[i][c] = dp[i - 1][c];
            if (w[i - 1] <= c) dp[i][c] = max(dp[i][c], dp[i - 1][c - w[i - 1]] + v[i - 1]);
        }
        cout << "After item " << i << ": B[" << i << "][" << capacity << "]=" << dp[i][capacity] << "\n";
    }
    vector<int> selected;
    int c = capacity;
    cout << "Backtracking from (" << n << "," << capacity << "):\n";
    for (int i = n; i >= 1; --i) {
        if (dp[i][c] > dp[i - 1][c]) {
            selected.push_back(i); c -= w[i - 1];
            cout << "item " << i << ": TAKE, remaining capacity=" << c << "\n";
        } else cout << "item " << i << ": SKIP\n";
    }
    reverse(selected.begin(), selected.end());
    cout << "Maximum value: " << dp[n][capacity] << "\nSelected item IDs: ";
    for (int id : selected) cout << id << ' ';
    cout << "\nTotal weight: " << capacity - c << " / " << capacity << "\n";
    return 0;
}
