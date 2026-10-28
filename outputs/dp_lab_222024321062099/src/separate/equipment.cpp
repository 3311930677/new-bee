#include <algorithm>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
using ll = long long;

int main() {
    int years, max_life;
    ll price;
    cout << "Equipment Renewal (Dynamic Programming)\n";
    cout << "Input years, max_life and purchase_price (press Enter for sample):\n";
    string line;
    getline(cin, line);
    bool sample = line.empty();
    if (sample) {
        years = 6; max_life = 5; price = 100;
    } else {
        istringstream header(line);
        if (!(header >> years >> max_life >> price) || years < 0 || years > 10000
            || max_life < 1 || max_life > 100 || price < 0 || price > 1000000000) {
            cerr << "ERROR: invalid planning horizon, life or price\n"; return 1;
        }
    }
    vector<ll> maintenance(max_life), salvage(max_life);
    if (sample) {
        maintenance = {10, 20, 40, 70, 110}; salvage = {60, 45, 30, 20, 10};
    } else {
        for (ll &x : maintenance) {
            if (!(cin >> x) || x < 0 || x > 1000000000) {
                cerr << "ERROR: invalid maintenance cost\n"; return 1;
            }
        }
        for (ll &x : salvage) {
            if (!(cin >> x) || x < 0 || x > price) {
                cerr << "ERROR: invalid salvage value\n"; return 1;
            }
        }
    }
    vector<ll> cycle(max_life + 1), dp(years + 1, numeric_limits<ll>::max() / 4);
    vector<int> previous(years + 1, -1);
    ll sum = 0;
    cout << "Cycle cost C[k] = price + maintenance(1..k) - salvage[k]\n";
    for (int k = 1; k <= max_life; ++k) {
        sum += maintenance[k - 1];
        cycle[k] = price + sum - salvage[k - 1];
        cout << "C[" << k << "]=" << cycle[k] << "  ";
    }
    cout << "\nState: F[t] = minimum cost to cover exactly t years\n";
    dp[0] = 0;
    for (int t = 1; t <= years; ++t) {
        cout << "F[" << t << "]: ";
        for (int k = 1; k <= min(t, max_life); ++k) {
            ll candidate = dp[t - k] + cycle[k];
            cout << "k=" << k << " -> " << candidate << "  ";
            if (candidate < dp[t]) { dp[t] = candidate; previous[t] = k; }
        }
        cout << "choose " << dp[t] << "\n";
    }
    vector<int> lives;
    for (int t = years; t > 0; t -= previous[t]) lives.push_back(previous[t]);
    reverse(lives.begin(), lives.end());
    cout << "Minimum total cost: " << dp[years] << "\nOptimal service lives: ";
    for (int k : lives) cout << k << ' ';
    cout << "\nReplacement plan:\n";
    int year = 1;
    for (int k : lives) {
        cout << "buy at start of year " << year << ", sell at end of year " << year + k - 1 << "\n";
        year += k;
    }
    return 0;
}
