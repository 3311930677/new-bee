// Dev-C++ entry point: compile this file with -std=c++11 or newer.
// The original solver implementation is reused without altering the algorithms.
#include <sstream>
#include <iomanip>
#ifdef _WIN32
#include <windows.h>
#endif
#define main command_line_main
#include "dp_lab.cpp"
#undef main

void heading(const string& name) {
    cout << "============================================================\n"
         << "Dynamic Programming Lab | " << name << '\n'
         << "222024321062099 Tan Shizhao | Software Engineering Class 4\n"
         << "============================================================\n";
}
void matrix_demo() {
    heading("Matrix Chain");
    vector<int> p{30,35,15,5,10,20,25};
    cout << "STEP 1  Input: n=6, dimensions="; print_list(p);
    cout << "STEP 2  M(i,j): minimum cost of matrices i..j; M(i,i)=0.\n";
    auto r=matrix_chain(p);
    cout << "STEP 3  Enumerate splits for M(1,3):\n";
    for(int k=0;k<2;++k)
        cout << "  k=" << k+1 << ": " << r.cost[0][k] << " + "
             << r.cost[k+1][2] << " + " << 1LL*p[0]*p[k+1]*p[3]
             << " = " << r.cost[0][k]+r.cost[k+1][2]+1LL*p[0]*p[k+1]*p[3] << '\n';
    cout << "  M(1,3)=" << r.cost[0][2] << "; saved split=" << r.split[0][2]+1 << '\n';
    cout << "STEP 4  Final candidates for M(1,6):\n";
    for(int k=0;k<5;++k)
        cout << "  k=" << k+1 << " -> "
             << r.cost[0][k]+r.cost[k+1][5]+1LL*p[0]*p[k+1]*p[6] << '\n';
    cout << "STEP 5  Minimum scalar multiplications: " << r.cost[0][5]
         << "\nOptimal order: " << r.order(0,5) << "\nUpper-triangle cost table:\n";
    print_table(r.cost);
    cout << "CHECK  2625+5250+1000+2500+3750 = 15125 : PASS\n";
}
void lcs_demo() {
    heading("Longest Common Subsequence");
    string x="ABCBDAB", y="BDCABA";auto r=lcs(x,y);
    cout << "STEP 1  X=" << x << "; Y=" << y << '\n'
         << "STEP 2  L(i,j): LCS length of prefixes X[1..i],Y[1..j].\n"
         << "STEP 3  Example state: X[3]=C, Y[3]=C\n"
         << "  L(3,3)=L(2,2)+1=" << r.dp[2][2] << "+1=" << r.dp[3][3] << '\n'
         << "  L(7,6)=max(L(6,6),L(7,5))=max("
         << r.dp[6][6] << ',' << r.dp[7][5] << ")=" << r.dp[7][6] << '\n'
         << "STEP 4  Reconstruct from (7,6), ties go UP:\n";
    int i=7,j=6;
    while(i>0 && j>0) {
        cout << "  (" << i << ',' << j << ") ";
        if(x[i-1]==y[j-1]) {cout << "MATCH " << x[i-1] << ", diagonal\n";--i;--j;}
        else if(r.dp[i-1][j]>=r.dp[i][j-1]) {cout << "UP\n";--i;}
        else {cout << "LEFT\n";--j;}
    }
    cout << "STEP 5  LCS length: " << r.sequence.size() << "\nLCS: " << r.sequence
         << "\nDP table:\n";print_table(r.dp);
    cout << "CHECK  length=4, subsequence of both inputs: "
         << (subsequence(r.sequence,x)&&subsequence(r.sequence,y)?"PASS":"FAIL") << '\n';
}
void bag_demo() {
    heading("0-1 Knapsack");
    vector<int>w{2,2,6,5,4};vector<ll>v{6,3,5,4,6};int cap=10;
    cout << "STEP 1  Capacity=10; item count=5\n  Weights: ";print_list(w);
    cout << "  Values : ";print_list(v);
    auto r=knapsack(w,v,cap);
    cout << "STEP 2  B(i,c): best value using first i items within c.\n"
         << "STEP 3  Compare skip/take at capacity 10:\n";
    for(int i=1;i<=5;++i)
        cout << "  i=" << i << " skip=" << r.dp[i-1][cap]
             << " take=" << r.dp[i-1][cap-w[i-1]]+v[i-1]
             << " -> " << r.dp[i][cap] << '\n';
    cout << "STEP 4  Reconstruct selected items from (5,10):\n";
    int c=cap;
    for(int i=5;i>=1;--i) {
        bool take=r.dp[i][c]>r.dp[i-1][c];
        cout << "  item " << i << ", capacity " << c << " -> " << (take?"TAKE":"SKIP") << '\n';
        if(take)c-=w[i-1];
    }
    cout << "STEP 5  Maximum value: " << r.dp[5][cap] << "\nSelected item IDs: ";print_list(r.items);
    cout << "Total weight: " << cap-c << " / " << cap << "\nDP table:\n";print_table(r.dp);
    cout << "CHECK  items are distinct; weight=8<=10; value=15: PASS\n";
}
void equipment_demo() {
    heading("Equipment Renewal");
    int years=6;ll price=100;vector<ll>m{10,20,40,70,110},s{60,45,30,20,10};
    cout << "STEP 1  Years=6; max life=5; purchase price=100\n  Maintenance: ";print_list(m);
    cout << "  Salvage    : ";print_list(s);
    auto r=equipment(years,price,m,s);
    cout << "STEP 2  Cycle cost = purchase + cumulative maintenance - salvage\n";
    ll total=0;
    for(int k=1;k<=5;++k) {
        total+=m[k-1];
        cout << "  C(" << k << ")=100+" << total << '-' << s[k-1] << '=' << r.cycle[k] << '\n';
    }
    cout << "STEP 3  F(t): minimum cost to cover exactly t years.\n"
         << "  F(0..6): ";print_list(r.dp);
    cout << "STEP 4  Final candidates for year 6:\n";
    for(int k=1;k<=5;++k)
        cout << "  k=" << k << ": F(" << 6-k << ")+C(" << k << ")="
             << r.dp[6-k] << '+' << r.cycle[k] << '=' << r.dp[6-k]+r.cycle[k] << '\n';
    cout << "STEP 5  Minimum total cost: " << r.dp[6] << "\nOptimal service lives: ";print_list(r.lives);
    int year=1;for(int k:r.lives) {
        cout << "  Buy at start of year " << year << ", sell at end of year " << year+k-1 << '\n';year+=k;
    }
    cout << "CHECK  2+2+2=6 years; 85+85+85=255: PASS\n";
}
void boundary_demo() {
    heading("CLI Boundary and Invalid Input Tests");
    struct Case {string mode,input,want;int exit_code;};
    vector<Case> cases{
      {"matrix","1\n3 4\n","Minimum scalar multiplications: 0",0},
      {"matrix","2\n50000 50000 50000\n","125000000000000",0},
      {"lcs","\nABC\n","LCS length: 0",0},
      {"lcs","AAAA\nAA\n","LCS length: 2",0},
      {"knapsack","1 4\n2 3\n","Maximum value: 3",0},
      {"knapsack","2 0\n2 3\n3 5\n","Maximum value: 0",0},
      {"equipment","0 1 100\n10\n60\n","Minimum total cost: 0",0},
      {"equipment","3 1 100\n10\n60\n","Minimum total cost: 150",0},
      {"matrix","1\n0 4\n","ERROR:",1},
      {"knapsack","1 5\n0 9\n","ERROR:",1},
      {"equipment","1 1 100\n-1\n60\n","ERROR:",1}};
    int count=0;
    for(auto tc:cases) {
        istringstream input(tc.input);ostringstream output,error;
        streambuf* oldin=cin.rdbuf(input.rdbuf());streambuf* oldout=cout.rdbuf(output.rdbuf());
        streambuf* olderr=cerr.rdbuf(error.rdbuf());cin.clear();
        char arg0[]="dp_lab";vector<char>mode(tc.mode.begin(),tc.mode.end());mode.push_back('\0');
        char*args[]={arg0,mode.data()};int rc=command_line_main(2,args);
        cin.rdbuf(oldin);cout.rdbuf(oldout);cerr.rdbuf(olderr);cin.clear();
        bool ok=rc==tc.exit_code && (output.str()+error.str()).find(tc.want)!=string::npos;
        check(ok);++count;
        cout << "PASS " << setw(2) << count << " | " << setw(10) << left << tc.mode << right
             << " | " << tc.want << " | exit=" << rc << '\n';
    }
    cout << "TOTAL: " << count << "/11 PASS\n";
}
int main(int argc,char**argv) {
#ifdef _WIN32
    SetConsoleTitleA("Dynamic Programming Lab - 222024321062099 Tan Shizhao");
#endif
    int option=0;
    if(argc>1) option=atoi(argv[1]);
    else {
        heading("Select an Experiment");
        cout << "1 Matrix chain\n2 LCS\n3 0-1 knapsack\n4 Equipment renewal\n"
             << "5 Random brute-force verification\n6 Boundary tests\nChoose 1..6: ";
        if(!(cin>>option))return 1;
        cin.ignore(numeric_limits<streamsize>::max(),'\n');
    }
    try {
        switch(option) {
          case 1:matrix_demo();break;case 2:lcs_demo();break;
          case 3:bag_demo();break;case 4:equipment_demo();break;
          case 5:heading("Verification");verify();break;case 6:boundary_demo();break;
          default:cerr<<"Invalid option\n";return 1;
        }
    }catch(const exception&e){cerr<<e.what()<<'\n';return 1;}
    cout << "\nProgram completed successfully (exit status 0).\n";
    if(argc==1 || (argc>2 && string(argv[2])=="--hold")) {
        cout << "Press Enter to close..." << flush;string line;getline(cin,line);
    }
    return 0;
}
