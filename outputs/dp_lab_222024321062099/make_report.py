from pathlib import Path
import json
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
ROOT=Path(__file__).resolve().parent
doc=Document()
s=doc.sections[0]
s.page_width=Inches(8.5);s.page_height=Inches(11)
s.top_margin=s.bottom_margin=Inches(.72)
s.left_margin=s.right_margin=Inches(.82)
s.footer_distance=Inches(.3)
for name in ['Normal','Title','Subtitle','Heading 1','Heading 2','Caption']:
 st=doc.styles[name];st.font.name='宋体';st._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'宋体')
 st.font.color.rgb=RGBColor(0,0,0)
 st.font.size=Pt(11)
 st.paragraph_format.space_after=Pt(7)
 st.paragraph_format.line_spacing=1.25
doc.styles['Title'].font.size=Pt(24)
doc.styles['Subtitle'].font.size=Pt(13)
doc.styles['Subtitle'].font.italic=False
for name,size in [('Heading 1',17),('Heading 2',12)]:
 doc.styles[name].font.name='黑体';doc.styles[name]._element.rPr.rFonts.set(qn('w:eastAsia'),'黑体')
 doc.styles[name].font.size=Pt(size);doc.styles[name].font.bold=True
 doc.styles[name].paragraph_format.space_before=Pt(10)
doc.styles['Caption'].font.size=Pt(10)
doc.core_properties.author='谈世钊'
doc.core_properties.title='实验二 动态规划实验报告'
doc.core_properties.subject='矩阵连乘 最长公共子序列 0-1背包'
footer=s.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.CENTER
fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');footer._p.append(fld)

def p(t='',bold=False):
 z=doc.add_paragraph();z.paragraph_format.first_line_indent=Pt(22)
 r=z.add_run(t);r.bold=bold;return z
def h(t):doc.add_heading(t,level=2)
def page(t,first=False):
 if not first:doc.add_page_break()
 doc.add_heading(t,level=1)
def eq(t):
 z=doc.add_paragraph();z.alignment=WD_ALIGN_PARAGRAPH.CENTER
 om=OxmlElement('m:oMath');r=OxmlElement('m:r');txt=OxmlElement('m:t');txt.text=t;r.append(txt);om.append(r);z._p.append(om)
def code(t):
 z=doc.add_paragraph();z.paragraph_format.line_spacing=1.03;z.paragraph_format.space_after=Pt(8)
 for i,line in enumerate(t.strip('\n').splitlines()):
  r=z.add_run(('\n' if i else '')+line);r.font.name='Consolas';r.font.size=Pt(9.5)
  r._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'宋体')
 return z
def table(headers,rows,widths=None):
 t=doc.add_table(rows=1, cols=len(headers));t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
 if widths:
  for col,w in zip(t.columns,widths):col.width=Inches(w)
 for c,txt in zip(t.rows[0].cells,headers):c.text=str(txt)
 for row in rows:
  for c,txt in zip(t.add_row().cells,row):c.text=str(txt)
 for ri,row in enumerate(t.rows):
  trPr=row._tr.get_or_add_trPr();cant=OxmlElement('w:cantSplit');trPr.append(cant)
  for ci,c in enumerate(row.cells):
   if widths:c.width=Inches(widths[ci])
   c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
   tcPr=c._tc.get_or_add_tcPr();borders=OxmlElement('w:tcBorders')
   for edge in ['top','left','bottom','right']:
    b=OxmlElement('w:'+edge);b.set(qn('w:val'),'single');b.set(qn('w:sz'),'5');b.set(qn('w:color'),'D9D9D9');borders.append(b)
   tcPr.append(borders)
   margins=OxmlElement('w:tcMar')
   for edge in ['top','left','bottom','right']:
    m=OxmlElement('w:'+edge);m.set(qn('w:w'),'75');m.set(qn('w:type'),'dxa');margins.append(m)
   tcPr.append(margins)
   if ri==0:
    sh=OxmlElement('w:shd');sh.set(qn('w:fill'),'E8EDF2');tcPr.append(sh)
   for pp in c.paragraphs:
    pp.alignment=WD_ALIGN_PARAGRAPH.CENTER;pp.paragraph_format.space_after=Pt(2);pp.paragraph_format.line_spacing=1.1
    for rr in pp.runs:rr.font.size=Pt(10);rr.bold=ri==0
 rpt=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(rpt)
 zz=doc.add_paragraph();zz.paragraph_format.space_after=Pt(0);zz.paragraph_format.line_spacing=Pt(2);zz.add_run().font.size=Pt(2)
 return t
def shot(name,caption,maxh=4.8):
 from PIL import Image
 img=ROOT/'evidence'/f'{name}.png'
 with Image.open(img) as im: w,hh=im.size
 ww=min(6.78,min(maxh,3.7)*w/hh)
 z=doc.add_paragraph();z.alignment=WD_ALIGN_PARAGRAPH.CENTER
 z.paragraph_format.space_after=Pt(4);z.add_run().add_picture(str(img),width=Inches(ww))
 cap=doc.add_paragraph(caption,'Caption');cap.alignment=WD_ALIGN_PARAGRAPH.CENTER

z=doc.add_paragraph('数据结构与算法综合实训','Subtitle');z.alignment=WD_ALIGN_PARAGRAPH.CENTER
z=doc.add_paragraph('实验二 动态规划实验报告','Title');z.alignment=WD_ALIGN_PARAGRAPH.CENTER
for t in ['学号  222024321062099','姓名  谈世钊','班级  软工中外4班']:
 z=doc.add_paragraph(t);z.alignment=WD_ALIGN_PARAGRAPH.CENTER;z.runs[0].font.size=Pt(14)
h('实验内容与目标')
p('本实验使用 C++17 实现矩阵连乘、最长公共子序列和 0-1 背包，本报告选取三个代表性题目。每个问题均给出状态定义、递推关系、边界条件、计算顺序及最优方案恢复方法。通过典型算例、随机穷举对照和边界测试，验证最优值与输出方案的一致性。')
table(['实验项目','求解目标','典型算例结果'],[
 ['矩阵连乘','最少标量乘法次数','15125'],['最长公共子序列','最大公共子序列长度','4，输出 BCBA'],
 ['0-1 背包','容量约束下的最大价值','15，选择 1、2、5']], [1.5,3.0,2.28])
h('实验环境与完成情况')
p('硬件环境为本机 PC，操作系统为 Windows。编译器为 MinGW g++ 13.2.0，采用 C++17 标准，启用 -O2、-Wall、-Wextra 和 -pedantic。程序编译通过，三类算法共完成 600 组随机穷举对照、8 项内置边界检查及 11 项额外命令行测试，全部通过。')
p('报告中的运行图全部来自本机真实 Windows 编译终端：画面包含 g++ 编译命令、BUILD SUCCESS、样例输入、状态计算、回溯过程、边界错误提示和最终结果。对应的原始输入、输出、源码和复现脚本保存在实验附件中。')

page('一 动态规划原理与总体设计')
h('1 最优子结构与重叠子问题')
p('动态规划将原问题组织为相互依赖的子问题，保存已经求出的状态值，并按依赖关系计算新状态。最优子结构要求最优解中包含的子问题解也是相应条件下的最优解；重叠子问题说明不同求解路径会重复访问同一状态，保存结果可以减少重复计算。')
p('最优子结构可以用替换法说明：若最优方案包含一个非最优的子方案，且用更好的子方案替换后不会破坏约束，则原方案还能改进，与最优性矛盾。使用该论证时必须明确状态保留了哪些约束，不能只凭“问题可分解”就使用动态规划。')
h('2 状态设计与计算顺序')
table(['问题','状态含义','依赖方向'],[
 ['矩阵连乘','区间内矩阵乘积的最低代价','短区间到长区间'],
 ['最长公共子序列','两个前缀的 LCS 长度','短前缀到长前缀'],
 ['0-1 背包','前若干件物品在给定容量内的最大价值','上一物品层到下一层']],[1.35,3.85,1.58])
h('3 从最优值恢复最优方案')
p('仅保存最优值不足以展示完整答案。矩阵连乘记录最优断开点；LCS 按状态相等或相邻最优值回退；背包比较相邻物品层决定是否选择；报告分别检查括号结构、公共子序列合法性和物品总重量。')
h('4 实验实施步骤')
p('先用小规模数据人工计算期望结果，再实现递推与回溯，最后用不带记忆化的穷举算法作为独立参照。所有随机测试采用固定种子 20261027，便于重现。主程序按 matrix、lcs、knapsack 和 verify 四种模式运行，各模式的输入格式独立。')
p('本实验采用自底向上的表格法。状态初值、有效范围与循环顺序都在计算前确定；遇到无效维度或非正重量时，程序输出错误信息并返回非零退出码。')

page('二 矩阵连乘问题建模')
h('1 问题与输入数据')
p('设有 n 个相容矩阵，矩阵 Ai 的行数为 p(i−1)，列数为 p(i)。矩阵乘法满足结合律，不同括号化方式得到相同的数学乘积，但所需的标量乘法次数可能差别很大。目标是保持矩阵顺序不变，寻找乘法次数最少的括号化方式。')
table(['矩阵','行数','列数'],[['A1',30,35],['A2',35,15],['A3',15,5],['A4',5,10],['A5',10,20],['A6',20,25]],[2.2,2.2,2.38])
h('2 状态与递推关系')
p('数学说明使用从 1 开始的矩阵编号。M(i,j) 表示 Ai 到 Aj 连乘的最少乘法次数，S(i,j) 保存最后一次乘法的断开位置。单个矩阵无需相乘，故 M(i,i)=0。对于 i<j，枚举最后断开位置 k，左右乘积的维度分别为 p(i−1)×p(k) 和 p(k)×p(j)。')
eq('M(i,j) = min { M(i,k) + M(k+1,j) + p(i−1)·p(k)·p(j) }')
p('其中 k 从 i 到 j−1。每个候选值由左区间成本、右区间成本和最后合并成本组成。选取最小值并保存 k，之后可以递归输出完整括号表达式。')
h('3 正确性与数据结构')
p('最优括号结构一定有一个最终断开点。固定该断开点后，如果任一子区间存在更优括号结构，替换后会降低总成本，因此左右子区间必须分别最优。枚举所有最终断开点即可覆盖所有可能最优结构。')
p('程序使用 vector<int> 保存维度，使用二维 vector<long long> 保存代价，使用二维 vector<int> 保存断开点。代码从 0 开始编号，因此合并成本写为 p[i]×p[k+1]×p[j+1]。维度乘法通过 1LL 提升为 64 位计算。')

page('三 矩阵连乘算法与关键实现')
h('1 伪代码')
code('''M[i,i] ← 0
for len ← 2 to n:
    for i ← 1 to n−len+1:
        j ← i+len−1; M[i,j] ← INF
        for k ← i to j−1:
            q ← M[i,k]+M[k+1,j]+p[i−1]*p[k]*p[j]
            if q < M[i,j]: M[i,j] ← q; S[i,j] ← k
PrintOrder(i,j):
    if i=j: output Ai
    else: output '(' + PrintOrder(i,S[i,j])
                 + '×' + PrintOrder(S[i,j]+1,j) + ')' ''')
h('2 关键 C++ 代码')
code('''// i、j、k 为 0 基下标；按区间长度递增计算。
for (int len = 2; len <= n; ++len)
    for (int i = 0; i + len <= n; ++i) {
        int j = i + len - 1;
        r.cost[i][j] = INF;
        for (int k = i; k < j; ++k) {
            ll q = r.cost[i][k] + r.cost[k + 1][j]
                 + 1LL * p[i] * p[k + 1] * p[j + 1];
            if (q < r.cost[i][j]) {
                r.cost[i][j] = q;
                r.split[i][j] = k; // 保存回溯决策
            }
        }
    }''')
h('3 实现要点')
p('如果直接按照 i、j 的普通双重循环填表，可能在子区间尚未计算时就读取其初值。按 len 从小到大计算能够确保依赖全部就绪。严格小于时才更新，使相同成本的多个答案具有稳定的断开点选择。')
p('代价表只有上三角有效；截图中的下三角 0 是未使用的存储单元。INF 取 long long 最大值的四分之一。输入最多 100 个矩阵、每个维度不超过 10⁵，最多 99 次矩阵合并的总代价不超过 9.9×10¹⁶，小于 INF，也小于 64 位有符号整数上界。')

page('四 矩阵连乘运行结果与核验')
shot('matrix_compile','图1 本机编译器终端中的 g++ 编译命令与 BUILD SUCCESS',2.35)
shot('matrix_terminal','图2 真实终端运行矩阵连乘的输入、状态计算和最终结果',3.25)
h('1 结果解释')
p('程序得到最少乘法次数 15125，括号结构为 ((A1×(A2×A3))×((A4×A5)×A6))。维度数组为 30、35、15、5、10、20、25。')
table(['计算阶段','标量乘法次数','阶段结果维度'],[
 ['A2×A3',2625,'35×5'],['A1×(A2×A3)',5250,'30×5'],
 ['A4×A5',1000,'5×20'],['(A4×A5)×A6',2500,'5×25'],['左右两部分合并',3750,'30×25']],[3.0,1.8,1.98])
p('上表成本之和为 15125。按原顺序从左向右相乘的成本为 40500，优化后减少 25375 次，约为 62.65%。该比较仅表示此算例的运算次数差异，不等同于所有输入都能获得相同比例的时间收益。')

page('五 最长公共子序列问题建模')
h('1 子序列与子串的区别')
p('子序列保留原字符的先后顺序，但不要求连续；子串要求连续。本实验寻找两个字符串的最长公共子序列，不能在字符不相等时直接把状态置零。典型输入 X=ABCBDAB，Y=BDCABA，目标是输出长度和一个具体的公共子序列。')
h('2 状态与边界条件')
p('L(i,j) 表示 X 的前 i 个字符和 Y 的前 j 个字符的 LCS 长度。任意字符串与空串的公共子序列长度都为 0，因此第 0 行和第 0 列初始化为 0。')
eq('L(i,j) = L(i−1,j−1) + 1')
p('上式适用于 X 的第 i 个字符与 Y 的第 j 个字符相同的情况；相同末尾字符可接在较短前缀的公共子序列后面。若两者不同，至少有一个末尾字符不在当前最优公共子序列中。')
eq('L(i,j) = max { L(i−1,j), L(i,j−1) }')
h('3 计算与恢复路径')
p('从左上向右下填表，每个状态只依赖上方、左方和左上方。回溯从右下角开始：字符相等则记录该字符并同时减少 i 和 j；否则进入较大的相邻状态；相等时固定向上回退。回溯得到的字符顺序是反向的，最后必须反转。')
table(['数据结构','用途','规模'],[['string x、y','保存两个输入序列','m+n 个字符'],
 ['二维整数表 dp','保存各前缀的 LCS 长度','(m+1)×(n+1)'],['string sequence','保存恢复出的一个 LCS','最多 min(m,n) 个字符']],[1.7,3.1,1.98])
h('4 正确性说明')
p('若末尾字符不同，任何公共子序列不可能同时使用这两个末尾字符，因此它一定属于去掉 X 末尾或去掉 Y 末尾的某个子问题。若末尾相同，可在相应较短前缀的最优公共子序列后加入这一字符。结合空串边界，按前缀长度递增的归纳可得到最终最优长度。')
p('LCS 可能不唯一，不能只把某一个固定字符串当成唯一正确答案。验证时同时检查长度最优、结果为 X 的子序列、结果为 Y 的子序列。')

page('六 最长公共子序列算法与关键实现')
h('1 伪代码')
code('''L[0,*] ← 0; L[*,0] ← 0
for i ← 1 to m:
    for j ← 1 to n:
        if X[i]=Y[j]: L[i,j] ← L[i−1,j−1]+1
        else: L[i,j] ← max(L[i−1,j],L[i,j−1])
i ← m; j ← n; answer ← empty
while i>0 and j>0:
    if X[i]=Y[j]: append X[i]; i←i−1; j←j−1
    else if L[i−1,j] >= L[i,j−1]: i←i−1
    else: j←j−1
reverse(answer)''')
h('2 关键 C++ 代码')
code('''for (int i = 1; i <= m; ++i)
    for (int j = 1; j <= n; ++j)
        r.dp[i][j] = x[i - 1] == y[j - 1]
            ? r.dp[i - 1][j - 1] + 1
            : max(r.dp[i - 1][j], r.dp[i][j - 1]);
// 回溯构造一个答案；平局时向上移动。
for (int i = m, j = n; i > 0 && j > 0;) {
    if (x[i - 1] == y[j - 1]) {
        r.sequence += x[i - 1]; --i; --j;
    } else if (r.dp[i - 1][j] >= r.dp[i][j - 1]) --i;
    else --j;
}
reverse(r.sequence.begin(), r.sequence.end());''')
h('3 输入与边界处理')
p('程序使用 getline 分别读取两行，允许某行为空。读取 Windows 换行时去掉行末可能残留的回车字符。字符串长度均限制为 2000，以控制二维表的内存开销。命令行输入模式不先用 >> 读取数字，因而不会遗留一个多余换行。')
p('当前字符串以字节作为序列元素，适合本实验的 ASCII 英文字母。若将该实现用于中文 UTF-8 文本，应先将字符串解码为 Unicode 码点序列，再执行同样的动态规划；不能把 UTF-8 字节序列的公共片段直接解释为中文字符。')

page('七 最长公共子序列运行结果与核验')
shot('lcs','图3 真实编译终端中的 LCS 编译、回溯和运行结果',4.8)
h('1 长度与方案核验')
p('程序输出长度 4，序列 BCBA。在 X=ABCBDAB 中，可以选择第 2、3、4、6 个字符；在 Y=BDCABA 中，可以选择第 1、3、5、6 个字符。两个位置序列都严格递增，因此 BCBA 是合法公共子序列。')
h('2 状态表解释')
p('截图首行、首列为 0，对应空前缀。最后一行最后一列为 4，表明完整字符串的最优长度为 4。字符不相等时，状态沿上方或左方传播已有最优值，因此表中出现连续不变区域属于正常现象。')
p('另一种长度为 4 的公共子序列可能同样正确。本实现平局时向上回退，因此稳定输出 BCBA；不能因为输出与其他程序不同就判定错误。随机测试通过枚举 X 的所有子序列求真实最优长度，再分别检查输出在 X 和 Y 中的合法性。')
h('3 补充算例')
p('空串与 ABC 的期望长度为 0；ABC 与 XYZ 的期望长度为 0；AAAA 与 AA 的期望长度为 2。这三类输入分别检查空边界、无公共字符和重复字符的处理。')

page('八 0-1 背包问题建模')
h('1 输入与约束')
p('给定 n 件物品，第 i 件重量为 w(i)，价值为 v(i)，背包容量为 C。每件物品最多选一次，要求总重量不超过 C，且总价值最大。允许不装满背包，也允许空集合；本实验要求重量为正整数、价值为非负整数。')
table(['物品编号','重量','价值'],[[1,2,6],[2,2,3],[3,6,5],[4,5,4],[5,4,6]],[2.2,2.2,2.38])
p('典型输入的容量为 10。重量相同的第 1、2 件物品仍然是不同物品，状态必须保留处理到哪一件物品的信息，不能按重量去重。')
h('2 状态转移')
p('B(i,c) 表示仅使用前 i 件物品、容量不超过 c 时可获得的最大价值。第 0 层均为 0。对于第 i 件物品，若重量超过 c，则只能不选；否则比较不选与选取后的价值。')
eq('B(i,c) = max { B(i−1,c), B(i−1,c−w(i)) + v(i) }')
p('上式仅在 c≥w(i) 时使用。选取分支必须读取上一层 i−1 的状态，避免同一物品在同一层被反复选入。边界 B(i,0)=0 来自容量为零且重量为正的约束。')
h('3 正确性与方案恢复')
p('最优方案要么不含第 i 件物品，要么包含它。不含时答案属于前 i−1 件的子问题；包含时去掉该物品，余下物品必须在剩余容量内达到最优，否则可替换得到更大价值。两类互斥情况覆盖所有可行方案。')
p('程序保存 (n+1)×(C+1) 个 long long 状态。回溯时若 B(i,c)>B(i−1,c)，则选择第 i 件并减去其重量；否则跳过。相等时跳过属于一种稳定的平局策略，并不影响最优价值。')

page('九 0-1 背包算法与关键实现')
h('1 伪代码')
code('''B[0,*] ← 0
for i ← 1 to n:
    for c ← 0 to C:
        B[i,c] ← B[i−1,c]
        if w[i] <= c:
            B[i,c] ← max(B[i,c],B[i−1,c−w[i]]+v[i])
c ← C; answer ← empty
for i ← n downto 1:
    if B[i,c] > B[i−1,c]:
        append i to answer; c ← c−w[i]
reverse(answer)''')
h('2 关键 C++ 代码')
code('''for (int i = 1; i <= n; ++i)
    for (int c = 0; c <= cap; ++c) {
        r.dp[i][c] = r.dp[i - 1][c]; // 不选第 i 件
        if (w[i - 1] <= c)
            r.dp[i][c] = max(r.dp[i][c],
                r.dp[i - 1][c - w[i - 1]] + v[i - 1]);
    }
int c = cap;
for (int i = n; i >= 1; --i)
    if (r.dp[i][c] > r.dp[i - 1][c]) {
        r.items.push_back(i); // 记录物品编号
        c -= w[i - 1];
    }
reverse(r.items.begin(), r.items.end());''')
h('3 空间优化与适用限制')
p('如果只需要最优价值，可以把二维表压缩为一维数组，但容量必须从 C 向下遍历至当前重量。逆序保证读取的是本轮处理之前的状态；正序会允许当前物品重复使用，变成完全背包的含义。')
p('本实验保留二维表，以清楚展示各阶段结果并可靠恢复选择方案。输入最多 500 件物品、容量最多 10000，每件价值不超过 10⁹；累计价值和状态值使用 long long。容量较大时，按容量展开的算法可能占用大量内存，需要根据实际参数选择其他实现。')

page('十 0-1 背包运行结果与核验')
shot('knapsack','图4 真实编译终端中的 0-1 背包编译、回溯和运行结果',4.7)
h('1 最优值与约束检查')
p('程序输出最大价值 15，选择第 1、2、5 件。总重量为 2+2+4=8，不超过容量 10；总价值为 6+3+6=15。该结果说明最优背包不一定恰好装满，剩余 2 个容量单位无法放入其他未选择物品。')
h('2 状态变化分析')
p('处理第 3 件物品后，容量 10 的最优值为 14，对应第 1、2、3 件。处理第 4 件后该位置仍为 14；处理第 5 件后变为 15，最终方案改为第 1、2、5 件。这体现动态规划会综合比较候选方案，而不是只按单件价值或重量作局部选择。')
h('3 区分 0-1 与完全背包')
p('额外测试仅有一件重量 2、价值 3 的物品，容量为 4。正确结果仍为 3，而不是 6。该测试已实际运行并通过，可有效发现错误使用当前层状态或一维正序更新导致的重复选择问题。')

page('十一 随机穷举对照测试')
shot('verify','图5 真实编译终端中的三个选做程序综合验证',3.8)
h('1 对照方法与覆盖范围')
table(['算法','每类组数','穷举参照与规模'],[['矩阵连乘',200,'1至7个矩阵；递归枚举全部括号化'],
 ['最长公共子序列',200,'串长0至8；枚举第一个串的全部子序列'],
 ['0-1 背包',200,'0至10件；枚举全部物品子集']],[1.5,1.0,4.28])
p('随机数发生器采用 C++ mt19937，固定种子为 20261027。穷举参照直接按原始可行方案搜索，不使用动态规划表，也不复用待验证算法的最优值。三类各 200 组，随机对照共 600 组。')
h('2 同时验证数值与方案')
p('LCS 除了对比最优长度，还检查输出是否分别为两个输入串的子序列。背包重新累计回溯方案的重量与价值，并检查容量约束。矩阵连乘对照枚举全部括号化的最小代价，典型算例另行手算核验括号结构。')
p('600 组随机对照与 8 项内置检查均通过。该结果提高了对实现正确性的信心，但有限样本不能代替对所有输入的数学证明，特别是超出已声明输入范围的情况。')

page('十二 边界与非法输入测试')
shot('boundary','图6 真实编译终端中的非法输入和边界检查',4.6)
h('1 边界用例的作用')
p('单矩阵检验初值和零次运算；空串检验第 0 行或第 0 列；重复字符检验回溯；容量为零检验可行空集合；单件物品与两倍容量检验是否发生重复取用。')
h('2 数值范围与错误退出')
p('两个 50000×50000 的矩阵相乘需要 125000000000000 次标量乘法，明显超过 32 位有符号整数范围。该用例实际输出正确，说明维度乘积没有先在 int 范围内溢出后再赋给 long long。')
p('零维度矩阵和零重量物品均被拒绝。测试脚本同时检查错误信息包含 ERROR、退出码为 1，避免仅打印提示却继续输出看似有效的结果。额外命令行测试共 11 项，全部通过；与前一页的 608 项检查合计 619 项，其中部分边界场景有意重叠。')

page('十三 时间与空间复杂度分析')
h('1 矩阵连乘')
p('长度为 len 的区间共有 n−len+1 个，每个区间枚举 len−1 个断开点。所有候选转移数等于对 len=2 至 n 的 (n−len+1)(len−1) 求和，结果为 (n³−n)/6，因此填表时间为 O(n³)。两张 n×n 表的空间为 O(n²)。括号恢复访问各子区间结构；递归深度最坏为 O(n)。')
h('2 最长公共子序列')
p('共有 (m+1)(n+1) 个状态，每个非边界状态只做常数次比较和赋值，所以填表时间为 O(mn)。回溯每一步至少减小一个下标，最多 m+n 步，时间 O(m+n)。二维表空间 O(mn)，输出序列最多 min(m,n) 个字符。若只求长度，可以滚动两行并将较短串安排在列方向，把空间降至 O(min(m,n))。')
h('3 0-1 背包')
p('每件物品遍历从 0 到 C 的容量，共 n(C+1) 次，因此填表时间为 O(nC)。回溯逐件检查，时间为 O(n)。二维表占 O(nC) 空间；只求价值时一维数组可降为 O(C)。这里的 O(nC) 是伪多项式复杂度，因为输入整数 C 的二进制表示长度为 O(log C)，容量数值很大时并不意味着算法仍然高效。')
table(['算法','填表时间','主要存储','恢复答案'],[['矩阵连乘','O(n³)','O(n²)','保存断开点'],['LCS','O(mn)','O(mn)','沿表回溯'],['0-1 背包','O(nC)','O(nC)','逐件回溯'],],[1.6,1.5,1.7,1.98])
h('5 资源估计与取舍')
p('典型算例均很小，主要用于观察状态与核验答案，而非测量性能。LCS 在两串长度均为 2000 时，整数表约占 15.3 MiB；背包 n=500、C=10000 时，64 位表约占 38.2 MiB，不含容器等附加开销。保留完整表可使回溯和教学观察更直观，处理更大规模时应重新评估。')

page('十四 复现步骤与实现问题分析')
h('1 文件与编译运行')
p('三个独立源文件位于 src/matrix_chain.cpp、src/lcs.cpp 和 src/knapsack.cpp。evidence 目录保存输入文件、真实编译终端截图和复现脚本；三个程序可以分别在 Dev-C++ 中打开、编译和运行。')
code('''g++ -std=c++11 -O2 -Wall -Wextra -pedantic `
    src/matrix_chain.cpp -o matrix_chain.exe
g++ -std=c++11 -O2 -Wall -Wextra -pedantic `
    src/lcs.cpp -o lcs.exe
g++ -std=c++11 -O2 -Wall -Wextra -pedantic `
    src/knapsack.cpp -o knapsack.exe''')
p('三个模式运行后，分别输入相应截图中的标准输入内容；verify 不需手工输入。matrix 首行是矩阵数量，随后是 n+1 个维度；lcs 直接输入两行字符串；knapsack 输入物品数和容量，再输入每件重量与价值；')
h('2 关键问题及处理方法')
p('下标映射：数学推导采用 1 基编号，C++ 容器使用 0 基下标。矩阵维度映射、LCS 字符访问和背包物品编号均明确转换。输出物品及矩阵编号从 1 开始，便于与题意对应。')
p('最优值与方案一致性：如果只检查最优数值，回溯仍可能有下标或反序错误。实验对输出方案重新计算约束和代价，LCS 在回溯后反转，避免把逆向搜索顺序直接作为最终答案。')
p('模型边界：背包按“不超过容量”建模，允许剩余容量；矩阵连乘中的乘法次数使用 64 位整数，不把二维矩阵数据本身读入内存。')
p('错误处理：输入非法时通过异常返回错误信息和退出码 1。非正重量和无效维度已执行专门的负向测试。程序的输入限制是为本实验实现设置的范围，不能据此推断一般问题只能处理这些规模。')

page('十五 实验总结与改进建议')
h('1 实验结果与目标完成情况')
p('本实验完成三个动态规划程序，典型算例的最优值分别为 15125、4 和 15。每个问题均从输入约束出发定义状态，给出递推、边界、求值顺序和方案恢复方法；运行结果与人工核验及小规模穷举参照一致。源代码采用标准容器并对关键步骤添加注释，便于按模块阅读和复现。')
h('2 方法上的收获')
p('三个问题的共同点在于把选择的影响保留在状态中，然后枚举所有合法决策。它们的差别主要体现在依赖结构：矩阵连乘按区间长度组织，LCS 按两个前缀组织，背包增加物品阶段，因此，设计循环前应先画清状态依赖，而不是直接套用双重或三重循环。')
p('正确性需要同时考虑最优性与可行性。一个数字即使与样例相同，也不能说明输出方案满足原约束。LCS 的字符顺序和背包的取用次数都需要单独验证。将这些约束写成断言，可以让测试发现只看最后一个状态值时容易遗漏的问题。')
h('3 得失与局限')
p('完整二维表让状态变化和回溯过程清晰，但也带来较大的内存占用。随机穷举对照覆盖了大量小规模输入，便于发现边界和转移错误，但不能衡量超大输入下的速度，也不能保证未建模现实因素的合理性。')
p('本次没有把运行耗时作为结论依据，避免对非常短的程序用单次测量得出性能排序。后续若开展效率实验，应在相同编译配置下选取多个规模、重复运行，记录统计量，并把算法计算、输入输出和截图生成的时间分开。')
h('4 改进方向与实验建议')
p('实现方面，可增加只求最优值的空间压缩模式，并保留现有完整表模式用于解释和回溯；为 LCS 增加码点级输入处理；验证方面，可增加最大允许规模的资源检查，以及更多精心构造的平局和退化算例。')
p('实验任务说明可进一步明确选做题目数量，并明确选做题目的数量和范围。对实验教学，建议先用小表格手算说明状态含义，再要求给出独立对照方法，使报告不仅展示运行截图，还能够解释结果为什么正确。')

out=ROOT/'222024321062099谈世钊_选做三题_真实截图.docx'
# Remove decorative paragraph borders inherited from the base Word template.
for container in [doc._element,doc.styles._element]:
 for border in list(container.iter(qn('w:pBdr'))):border.getparent().remove(border)
doc.save(out)
print(out)
print('Designed pages: 16 (cover + 15 numbered sections)')
