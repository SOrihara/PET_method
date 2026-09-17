import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {marked} from 'marked';

// Edit README.md for the English guide; edit this file for its layout.
const pkg = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const version = /^Version:\s*(.+)$/m.exec(fs.readFileSync(path.join(pkg, 'DESCRIPTION'), 'utf8'))[1].trim();
const generated = new Date().toISOString().slice(0, 10);
const language = 'en';
const labels = {
  source: 'README.md', output: 'docs/index.html',
  title: 'PET: R Package Guide', windowTitle: 'PET | R Package Guide',
  contents: 'Contents', sidebar: 'User guide · English<br>Paper v2 / Development copy<br>Available offline',
  footer: `PET development version ${version} · Generated ${generated} · Guide text and figure are embedded in this HTML.`,
  copy: 'Copy', copied: 'Copied', selected: 'Selected', copyLabel: 'Copy code'
};
let body=marked.parse(fs.readFileSync(path.join(pkg,labels.source),'utf8'));
body=body.replace(/href="docs\/index\.html"/g,'href="index.html"');
body=body.replace('<h1>PET</h1>',`<h1>${labels.title}</h1>`);
let toc=[];let count=0;
body=body.replace(/<h2>(.*?)<\/h2>/g,(all,title)=>{count++;toc.push(`<a href="#section-${count}">${title}</a>`);return `<h2 id="section-${count}">${title}</h2>`;});
const png=fs.readFileSync(path.join(pkg,'docs/trajectory-fev.png')).toString('base64');
body=body.replace(/src="(?:docs\/)?trajectory-fev\.png"/,`src="data:image/png;base64,${png}"`);
body=body.replace(/<table>/g,'<div class="table-scroll"><table>').replace(/<\/table>/g,'</table></div>');
const html=`<!doctype html>
<html lang="${language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${labels.windowTitle}</title>
<style>
:root{--ink:#173533;--muted:#57716d;--accent:#12665f;--line:#d9e4df;--paper:#fff;--wash:#f3f7f4;--code:#142b2a}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:25px}body{margin:0;color:var(--ink);background:var(--wash);font-family:"Yu Gothic UI","Meiryo",system-ui,sans-serif;line-height:1.9;font-size:15px}a{color:var(--accent);text-underline-offset:3px}
.layout{max-width:1470px;margin:auto;display:grid;grid-template-columns:245px minmax(0,1fr);min-height:100vh}.sidebar{padding:46px 25px;position:sticky;top:0;height:100vh;border-right:1px solid var(--line);overflow:auto}.wordmark{font-family:Georgia,serif;font-size:48px;letter-spacing:-2px;line-height:1;color:#174b43}.tag{display:block;font-size:11px;letter-spacing:.12em;color:var(--muted);margin:18px 0 36px}.sidebar nav a{display:block;font-size:12px;line-height:1.6;color:#35544f;text-decoration:none;padding:9px 0;border-bottom:1px solid #e4ece7}.sidebar nav a:hover{color:#008579}.small{font-size:11px;color:var(--muted);margin-top:30px}
main{background:var(--paper);padding:54px 70px 80px;min-width:0}h1{font-family:"Yu Gothic UI",sans-serif;line-height:1.3;font-size:37px;letter-spacing:-.04em;margin:0 0 24px;border-top:5px solid var(--accent);padding-top:28px}h2{font-size:23px;line-height:1.5;margin:65px 0 24px;border-bottom:1px solid var(--line);padding-bottom:14px}h3{font-size:18px;margin-top:35px}p{margin:18px 0}main>p:nth-of-type(1){font-size:12px;letter-spacing:.04em;color:var(--accent);margin-bottom:30px}strong{font-weight:700}pre{position:relative;border-radius:8px;background:var(--code);color:#edf6f2;overflow:auto;padding:26px 24px;font-size:13px;line-height:1.7;margin:24px 0}code{font-family:Consolas,"Yu Gothic UI",monospace;font-size:.91em}p code,li code,td code{background:#edf4ef;padding:2px 5px;border-radius:4px;overflow-wrap:anywhere}.copy{position:absolute;right:10px;top:8px;background:#2a4945;border:1px solid #53716a;border-radius:4px;color:#e8f4ef;font-size:11px;padding:4px 9px;cursor:pointer}.copy:focus{outline:2px solid #a7ddcc}pre:has(.copy){padding-top:43px}
.table-scroll{overflow-x:auto;margin:25px 0}table{border-collapse:collapse;width:100%;font-size:13px}th{background:#edf4ef;text-align:left;border-top:1px solid var(--line);color:#254c43}td,th{padding:13px 15px;border-bottom:1px solid var(--line);vertical-align:top}td:first-child{min-width:155px}img{display:block;width:100%;height:auto;border:1px solid var(--line);border-radius:6px;margin:30px auto}li{margin:6px 0}footer{font-size:11px;color:var(--muted);border-top:1px solid var(--line);margin-top:60px;padding-top:20px}
@media(max-width:1000px){.layout{grid-template-columns:195px minmax(0,1fr)}main{padding:35px}.sidebar{padding:34px 18px}h1{font-size:31px}}@media(max-width:700px){.layout{display:block}.sidebar{position:relative;height:auto;border-right:0;padding:22px;border-bottom:1px solid var(--line)}.wordmark{font-size:32px}.tag{display:inline-block;margin:0 0 0 14px}.sidebar nav{display:none}.small{margin:8px 0 0}main{padding:28px 20px}h1{font-size:27px}h2{font-size:21px;margin-top:45px}pre{padding-left:14px;font-size:11px}body{font-size:14px}}
@media print{body{background:#fff}.layout{display:block}.sidebar,.copy{display:none}main{padding:0}h1{font-size:25px}h2{break-after:avoid;margin-top:30px}pre,table,img{break-inside:avoid}pre{white-space:pre-wrap;background:#f1f4f1;color:#163a33}a{color:inherit}footer{display:none}}
</style></head><body><div class="layout"><aside class="sidebar"><div class="wordmark">PET</div><span class="tag">R PACKAGE / ${version}</span><nav aria-label="${labels.contents}">${toc.join('')}</nav><p class="small">${labels.sidebar}</p></aside><main>${body}<footer>${labels.footer}</footer></main></div>
<script>const labels=${JSON.stringify({copy:labels.copy,copied:labels.copied,selected:labels.selected,copyLabel:labels.copyLabel})};document.querySelectorAll('pre').forEach(pre=>{const b=document.createElement('button');b.className='copy';b.type='button';b.textContent=labels.copy;b.setAttribute('aria-label',labels.copyLabel);b.onclick=async()=>{const t=pre.querySelector('code').textContent;try{await navigator.clipboard.writeText(t);b.textContent=labels.copied}catch{const s=getSelection();const r=document.createRange();r.selectNodeContents(pre.querySelector('code'));s.removeAllRanges();s.addRange(r);b.textContent=labels.selected}setTimeout(()=>b.textContent=labels.copy,1800)};pre.append(b)});</script></body></html>`;
fs.writeFileSync(path.join(pkg,labels.output),html);
console.log(`Built ${language} guide: ` + path.join(pkg,labels.output));
