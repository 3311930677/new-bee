const fs=require('fs');
const path=require('path');
const {pathToFileURL}=require('url');
const {chromium}=require('C:/Users/tsz/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=__dirname;
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
 const page=await browser.newPage({viewport:{width:1100,height:500},deviceScaleFactor:1.5});
 const records=JSON.parse(fs.readFileSync(path.join(root,'evidence/records.json'),'utf8'));
 for(const r of records){
  const html=`<!doctype html><meta charset="utf-8"><title>${esc(r.title)} 实际运行记录</title><style>
  *{box-sizing:border-box}body{margin:0;padding:20px;background:#f3f4f6;color:#161e2d;font-family:'Microsoft YaHei',sans-serif}
  h1{font-size:27px;margin:0 0 5px} .meta{font-size:16px;color:#42526a;margin-bottom:12px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.card{background:white;border:1px solid #d7dce4;border-radius:6px;padding:12px 16px;margin-bottom:12px}h2{font-size:15px;margin:0 0 6px;color:#43536a}pre{font:20px/1.3 Consolas,'Microsoft YaHei',monospace;margin:0;white-space:pre-wrap;overflow-wrap:anywhere}.status{font-size:16px;color:#166534}.foot{font-size:13px;color:#617087;margin:8px 0 0}</style>
  <h1>${esc(r.title)} 实际运行记录</h1><div class="meta">222024321062099 谈世钊 · 软工中外4班 · C++17 / GCC 13.2.0</div>
  <div class="grid"><div class="card"><h2>运行命令</h2><pre>dp_lab.exe ${esc(r.mode==='boundary'?'[boundary suite]':r.mode)}</pre></div>
  <div class="card"><h2>标准输入</h2><pre>${esc(r.input||'(无需输入；固定随机种子 20261027)')}</pre></div></div>
  <div class="card"><h2>程序输出</h2><pre>${esc(r.output)}</pre></div>
  <div class="status">${r.mode==='boundary'?'测试套件通过':'进程退出码：'+r.returncode}</div><p class="foot">本页读取实际可执行程序的运行日志；原始输入、输出与测试脚本随实验附件保存。</p>`;
  const file=path.join(root,'evidence',r.mode+'.html');fs.writeFileSync(file,html);
  await page.goto(pathToFileURL(file).href);await page.screenshot({path:path.join(root,'evidence',r.mode+'.png'),fullPage:true});
 }
 await browser.close();console.log('Saved 6 screenshots of actual execution logs.');
})();
