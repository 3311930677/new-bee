#include <algorithm>
#include <functional>
#include <iostream>
#include <limits>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>
using namespace std;
using ll = long long;
const ll INF = numeric_limits<ll>::max() / 4;

struct MatrixResult {
    vector<vector<ll>> cost;
    vector<vector<int>> split;
    string order(int i, int j) const {
        if (i == j) return "A" + to_string(i + 1);
        int k = split[i][j];
        return "(" + order(i, k) + " x " + order(k + 1, j) + ")";
    }
};
MatrixResult matrix_chain(const vector<int>& p) {
    int n = static_cast<int>(p.size()) - 1;
    if (n < 1) throw invalid_argument("at least one matrix required");
    for (int d : p) if (d < 1 || d > 100000)
        throw invalid_argument("dimensions must be in 1..100000");
    MatrixResult r{vector<vector<ll>>(n, vector<ll>(n)),
                   vector<vector<int>>(n, vector<int>(n, -1))};
    // Increasing interval length ensures both subproblems are ready.
    for (int len = 2; len <= n; ++len)
        for (int i = 0; i + len <= n; ++i) {
            int j = i + len - 1;
            r.cost[i][j] = INF;
            for (int k = i; k < j; ++k) {
                ll q = r.cost[i][k] + r.cost[k + 1][j]
                     + 1LL * p[i] * p[k + 1] * p[j + 1];
                if (q < r.cost[i][j]) {
                    r.cost[i][j] = q;
                    r.split[i][j] = k;
                }
            }
        }
    return r;
}
struct LcsResult { vector<vector<int>> dp; string sequence; };
LcsResult lcs(const string& x, const string& y) {
    int m = static_cast<int>(x.size()), n = static_cast<int>(y.size());
    LcsResult r{vector<vector<int>>(m + 1, vector<int>(n + 1)), ""};
    for (int i = 1; i <= m; ++i)
        for (int j = 1; j <= n; ++j)
            r.dp[i][j] = x[i - 1] == y[j - 1]
                ? r.dp[i - 1][j - 1] + 1
                : max(r.dp[i - 1][j], r.dp[i][j - 1]);
    // At a tie, go upward to make reconstruction deterministic.
    for (int i = m, j = n; i > 0 && j > 0;) {
        if (x[i - 1] == y[j - 1]) {
            r.sequence += x[i - 1]; --i; --j;
        } else if (r.dp[i - 1][j] >= r.dp[i][j - 1]) --i;
        else --j;
    }
    reverse(r.sequence.begin(), r.sequence.end());
    return r;
}
struct BagResult { vector<vector<ll>> dp; vector<int> items; };
BagResult knapsack(const vector<int>& w, const vector<ll>& v, int cap) {
    if (w.size() != v.size() || cap < 0)
        throw invalid_argument("invalid knapsack data");
    for (int a : w) if (a <= 0) throw invalid_argument("weights must be positive");
    int n = static_cast<int>(w.size());
    BagResult r{vector<vector<ll>>(n + 1, vector<ll>(cap + 1)), {}};
    for (int i = 1; i <= n; ++i)
        for (int c = 0; c <= cap; ++c) {
            r.dp[i][c] = r.dp[i - 1][c]; // Do not select item i.
            if (w[i - 1] <= c)
                r.dp[i][c] = max(r.dp[i][c],
                    r.dp[i - 1][c - w[i - 1]] + v[i - 1]);
        }
    int c = cap;
    for (int i = n; i >= 1; --i)
        if (r.dp[i][c] > r.dp[i - 1][c]) {
            r.items.push_back(i); c -= w[i - 1];
        }
    reverse(r.items.begin(), r.items.end());
    return r;
}
struct EquipmentResult { vector<ll> dp, cycle; vector<int> previous, lives; };
EquipmentResult equipment(int years, ll price, const vector<ll>& maintenance,
                          const vector<ll>& salvage) {
    if (years < 0 || price < 0 || maintenance.empty()
        || maintenance.size() != salvage.size())
        throw invalid_argument("invalid equipment data");
    int life = static_cast<int>(maintenance.size());
    EquipmentResult r{vector<ll>(years + 1, INF), vector<ll>(life + 1),
                      vector<int>(years + 1, -1), {}};
    ll sum = 0;
    for (int k = 1; k <= life; ++k) {
        if (maintenance[k - 1] < 0 || salvage[k - 1] < 0
            || salvage[k - 1] > price)
            throw invalid_argument("invalid maintenance or salvage");
        sum += maintenance[k - 1];
        r.cycle[k] = price + sum - salvage[k - 1];
    }
    r.dp[0] = 0;
    for (int t = 1; t <= years; ++t)
        for (int k = 1; k <= min(t, life); ++k)
            if (r.dp[t - k] + r.cycle[k] < r.dp[t]) {
                r.dp[t] = r.dp[t - k] + r.cycle[k];
                r.previous[t] = k;
            }
    for (int t = years; t > 0; t -= r.previous[t])
        r.lives.push_back(r.previous[t]);
    reverse(r.lives.begin(), r.lives.end());
    return r;
}
template<class T> void print_list(const vector<T>& a) {
    for (size_t i = 0; i < a.size(); ++i) cout << (i ? " " : "") << a[i];
    cout << '\n';
}
template<class T> void print_table(const vector<vector<T>>& a) {
    for (const auto& row : a) print_list(row);
}
ll matrix_brute(const vector<int>& p, int i, int j) {
    if (i == j) return 0;
    ll best = INF;
    for (int k = i; k < j; ++k)
        best = min(best, matrix_brute(p, i, k) + matrix_brute(p, k + 1, j)
                   + 1LL * p[i] * p[k + 1] * p[j + 1]);
    return best;
}
bool subsequence(const string& a, const string& b) {
    size_t i = 0;
    for (char c : b) if (i < a.size() && a[i] == c) ++i;
    return i == a.size();
}
void check(bool ok) { if (!ok) throw runtime_error("verification failed"); }
void verify() {
    mt19937 gen(20261027);
    for (int test = 0; test < 200; ++test) {
        int n = 1 + gen() % 7;
        vector<int> p(n + 1);
        for (int& d : p) d = 1 + gen() % 30;
        check(matrix_chain(p).cost[0][n - 1] == matrix_brute(p, 0, n - 1));
    }
    cout << "Matrix chain: 200/200 PASS (all parenthesizations)\n";
    for (int test = 0; test < 200; ++test) {
        string x, y;
        int m = gen() % 9, n = gen() % 9;
        for (int i = 0; i < m; ++i) x += char('A' + gen() % 4);
        for (int i = 0; i < n; ++i) y += char('A' + gen() % 4);
        int best = 0;
        for (int mask = 0; mask < (1 << m); ++mask) {
            string a;
            for (int i = 0; i < m; ++i) if (mask & (1 << i)) a += x[i];
            if (subsequence(a, y)) best = max(best, static_cast<int>(a.size()));
        }
        auto r = lcs(x, y);
        check(r.dp[m][n] == best && static_cast<int>(r.sequence.size()) == best
              && subsequence(r.sequence, x) && subsequence(r.sequence, y));
    }
    cout << "LCS: 200/200 PASS (enumerate subsequences + reconstruction)\n";
    for (int test = 0; test < 200; ++test) {
        int n = gen() % 11, cap = gen() % 25;
        vector<int> w(n); vector<ll> v(n);
        for (int i = 0; i < n; ++i) { w[i] = 1 + gen() % 10; v[i] = gen() % 31; }
        ll best = 0;
        for (int mask = 0; mask < (1 << n); ++mask) {
            int weight = 0; ll val = 0;
            for (int i = 0; i < n; ++i) if (mask & (1 << i)) {
                weight += w[i]; val += v[i];
            }
            if (weight <= cap) best = max(best, val);
        }
        auto r = knapsack(w, v, cap); int weight = 0; ll val = 0;
        for (int i : r.items) { weight += w[i - 1]; val += v[i - 1]; }
        check(r.dp[n][cap] == best && val == best && weight <= cap);
    }
    cout << "0-1 knapsack: 200/200 PASS (enumerate subsets + reconstruction)\n";
    for (int test = 0; test < 200; ++test) {
        int n = gen() % 9, life = 1 + gen() % 5; ll price = 100;
        vector<ll> m(life), s(life);
        for (int i = 0; i < life; ++i) { m[i] = gen() % 51; s[i] = gen() % 101; }
        auto r = equipment(n, price, m, s);
        function<ll(int)> brute = [&](int t) -> ll {
            if (t == 0) return 0;
            ll best = INF, sum = 0;
            for (int k = 1; k <= min(t, life); ++k) {
                sum += m[k - 1];
                best = min(best, price + sum - s[k - 1] + brute(t - k));
            }
            return best;
        };
        ll value = 0; for (int k : r.lives) value += r.cycle[k];
        check(r.dp[n] == brute(n) && value == r.dp[n]
              && accumulate(r.lives.begin(), r.lives.end(), 0) == n);
    }
    cout << "Equipment renewal: 200/200 PASS (enumerate all life partitions)\n";
    check(matrix_chain({50000,50000,50000}).cost[0][1] == 125000000000000LL);
    check(matrix_chain({3,4}).cost[0][0] == 0);
    check(lcs("", "ABC").sequence.empty());
    check(lcs("ABC", "XYZ").sequence.empty());
    check(knapsack({2}, {3}, 0).dp[1][0] == 0);
    check(knapsack({2}, {3}, 4).dp[1][4] == 3);
    check(equipment(0,100,{10},{60}).dp[0] == 0);
    bool rejected = false;
    try { matrix_chain({2,0}); } catch (const invalid_argument&) { rejected = true; }
    check(rejected);
    cout << "Explicit boundary/error checks: 8/8 PASS\nTOTAL: 808/808 PASS\n";
}
int main(int argc, char** argv) {
    try {
        if (argc != 2) throw invalid_argument("usage: dp_lab matrix|lcs|knapsack|equipment|verify");
        string mode = argv[1];
        if (mode == "verify") { verify(); return 0; }
        if (mode == "matrix") {
            int n; if (!(cin >> n) || n < 1 || n > 100)
                throw invalid_argument("matrix count must be in 1..100");
            vector<int> p(n + 1); for (int& x : p) if (!(cin >> x)) throw invalid_argument("missing dimension");
            auto r = matrix_chain(p);
            cout << "Minimum scalar multiplications: " << r.cost[0][n - 1] << '\n';
            cout << "Optimal order: " << r.order(0,n - 1) << "\nCost table (lower triangle unused):\n";
            print_table(r.cost);
        } else if (mode == "lcs") {
            string x,y; getline(cin,x); getline(cin,y);
            if (!x.empty() && x.back()=='\r') x.pop_back();
            if (!y.empty() && y.back()=='\r') y.pop_back();
            if (x.size()>2000 || y.size()>2000) throw invalid_argument("strings too long");
            auto r = lcs(x,y);
            cout << "LCS length: " << r.sequence.size() << "\nLCS: " << r.sequence << "\nDP table:\n";
            print_table(r.dp);
        } else if (mode == "knapsack") {
            int n,cap; if (!(cin>>n>>cap) || n<0 || n>500 || cap<0 || cap>10000)
                throw invalid_argument("invalid n or capacity");
            vector<int> w(n); vector<ll> v(n);
            for(int i=0;i<n;++i) if(!(cin>>w[i]>>v[i]) || v[i]<0 || v[i]>1000000000)
                throw invalid_argument("invalid item");
            auto r=knapsack(w,v,cap); int sum=0;
            for(int i:r.items) sum+=w[i-1];
            cout<<"Maximum value: "<<r.dp[n][cap]<<"\nSelected item IDs: "; print_list(r.items);
            cout<<"Total weight: "<<sum<<" / "<<cap<<"\nDP table:\n"; print_table(r.dp);
        } else if (mode == "equipment") {
            int n,l; ll p;
            if(!(cin>>n>>l>>p) || n<0 || n>10000 || l<1 || l>100 || p>1000000000)
                throw invalid_argument("invalid planning horizon, life or price");
            vector<ll> m(l),s(l);
            for(ll& x:m) if(!(cin>>x) || x>1000000000) throw invalid_argument("invalid maintenance");
            for(ll& x:s) if(!(cin>>x)) throw invalid_argument("missing salvage");
            auto r=equipment(n,p,m,s);
            cout<<"Cycle costs (index 0 unused): "; print_list(r.cycle);
            cout<<"Minimum total cost: "<<r.dp[n]<<"\nOptimal service lives: "; print_list(r.lives);
            cout<<"DP[0..N]: "; print_list(r.dp);
            int year=1; for(int k:r.lives) {
                cout<<"Buy at start of year "<<year<<", sell at end of year "<<year+k-1<<'\n'; year+=k;
            }
        } else throw invalid_argument("unknown mode");
        if(cin.fail() && !cin.eof()) throw invalid_argument("invalid input");
        return 0;
    } catch(const exception& e) { cerr<<"ERROR: "<<e.what()<<'\n'; return 1; }
}
