///|
/// Escape text for XML/HTML content and quoted attributes.
fn evidence_escape(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .replace(old="'", new="&#39;")
}

///|
/// Self-contained viewer. Target data lives in escaped inert text, never in a
/// script literal or innerHTML. No network, CDN, tracking, or active target IO.
pub fn evidence_html(report : Json) -> String {
  let page =
    #|<!doctype html><html lang="en"><meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width,initial-scale=1">
    #|<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:">
    #|<title>MoonStateLens · Evidence Observatory</title>
    #|<style>
    #|:root{color-scheme:dark;--bg:#080e18;--panel:#111c2d;--line:#273d53;--cyan:#75f5de;--text:#e5edf7;--muted:#99afc8}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 85% 0,#123247,transparent 55%),var(--bg);color:var(--text);font:15px/1.6 system-ui,sans-serif}main{max-width:1250px;margin:auto;padding:44px 24px}header{border-bottom:1px solid var(--line);padding-bottom:22px}small,.muted{color:var(--muted)}h1{font-size:38px;letter-spacing:-1px;margin:5px 0}h2{font-size:18px}strong{color:var(--cyan)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin:24px 0}.card,section{background:#111c2dcc;border:1px solid var(--line);border-radius:14px;padding:19px;margin-bottom:18px}.value{font:700 26px monospace;color:var(--cyan)}button,input,select{color:var(--text);background:#18293d;border:1px solid #38516a;border-radius:7px;padding:9px;margin:4px}button{cursor:pointer}button:hover{border-color:var(--cyan)}pre{white-space:pre-wrap;overflow-wrap:anywhere;color:#b8cfe4;font:13px/1.55 monospace}table{width:100%;border-collapse:collapse}td,th{text-align:left;border-bottom:1px solid var(--line);padding:10px;overflow-wrap:anywhere}th{color:var(--muted)}.scroll{overflow:auto}.bad{color:#ffac95}.good{color:var(--cyan)}svg{width:100%;min-height:180px}details{margin-top:18px}code{color:var(--cyan)}#payload{display:none}.notice{border-left:3px solid var(--cyan);padding-left:15px;color:var(--muted)}@media(max-width:650px){h1{font-size:29px}td,th{padding:6px}main{padding:24px 12px}}
    #|</style><main><header><small>MODEL INFERENCE / FRESH REPLAY / AUDITABLE EVIDENCE</small><h1>MoonStateLens <strong>Observatory</strong></h1><div id="subtitle" class="muted"></div></header>
    #|<div class="grid" id="metrics"></div><p class="notice">Model predictions and actual observations have different scopes. An incomplete run is never an unconditional pass. Coverage refers to the learned model. Differing contexts are not independent bug counts.</p>
    #|<section><h2>Inspect evidence</h2><label>Filter <input id="filter" placeholder="status, input or output"></label><div class="scroll"><table><thead><tr><th>Case / context</th><th>Status</th><th>Inputs</th><th>Evidence</th></tr></thead><tbody id="rows"></tbody></table></div><div id="pager"></div></section>
    #|<section id="trace"><h2>Trace explorer</h2><p class="muted">Select a row to inspect predicted and actual outputs step by step.</p><div id="trace-controls"></div><div id="trace-body"></div></section>
    #|<section id="models"><h2>Model transitions</h2><div id="model-content"></div></section>
    #|<details><summary>Full evidence JSON and reproducible configuration</summary><button id="download">Download JSON</button><pre id="raw"></pre></details>
    #|<footer class="muted">Offline report · no requests are sent to a component by this viewer.</footer></main>
    #|<pre id="payload">
  let tail =
    #|</pre><script>
    #|'use strict';
    #|const data=JSON.parse(document.getElementById('payload').textContent), $=id=>document.getElementById(id);
    #|const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text);if(cls)n.className=cls;return n};
    #|$('subtitle').textContent=(data.format||'Evidence report')+' · schema '+(data.version||'?');$('raw').textContent=JSON.stringify(data,null,2);
    #|const metrics={Complete:data.execution_complete??data.complete??'see scope'};if(data.passed!==undefined)metrics.Passed=data.passed;if(data.confirmed_contexts!==undefined)metrics['Confirmed contexts']=data.confirmed_contexts;if(data.confirmed_violations!==undefined)metrics['Confirmed violations']=data.confirmed_violations;const resets=data.statistics?.resets??data.completed_physical_queries??(data.left_statistics&&data.right_statistics?data.left_statistics.resets+data.right_statistics.resets:undefined);if(resets!==undefined)metrics['Physical resets']=resets;if(data.failed_cases!==undefined)metrics['Failed cases']=data.failed_cases;if(data.pending_cases!==undefined)metrics['Pending cases']=data.pending_cases;if(data.prediction?.visited_pairs!==undefined)metrics['Product states']=data.prediction.visited_pairs;
    #|Object.entries(metrics).forEach(([k,v])=>{const c=el('div',undefined,'card');c.append(el('small',k),el('div',v,'value'));$('metrics').append(c)});
    #|const entries=data.cases||data.findings||[],size=40;let page=0,current=null,step=0;
    #|function render(){const q=$('filter').value.toLowerCase(),items=entries.map((v,i)=>({v,i})).filter(x=>JSON.stringify(x.v).toLowerCase().includes(q));$('rows').replaceChildren();items.slice(page*size,(page+1)*size).forEach(({v,i})=>{const tr=el('tr'),b=el('button',v.rule?.id??v.case??i);b.onclick=()=>select(v);const first=el('td');first.append(b);tr.append(first,el('td',v.status||'unknown',(v.status||'').includes('confirmed')||v.status==='failed'?'bad':'good'),el('td',JSON.stringify(v.inputs??v.prediction?.witness??[])),el('td',v.actual_outputs?'Fresh rule replay':v.actual_left?'Fresh replay on both targets':v.actual?'Baseline assertions':'Model / pending'));$('rows').append(tr)});$('pager').replaceChildren();const prev=el('button','Previous'),next=el('button','Next');prev.disabled=page===0;next.disabled=(page+1)*size>=items.length;prev.onclick=()=>{page--;render()};next.onclick=()=>{page++;render()};$('pager').append(prev,el('span',` ${items.length} entries · page ${page+1} `),next)}
    #|function select(v){current=v;step=0;showTrace()}
    #|function showTrace(){const v=current,inputs=v.inputs??v.prediction?.witness??[];$('trace-controls').replaceChildren();const prev=el('button','←'),next=el('button','→');prev.disabled=step===0;next.disabled=step>=inputs.length;prev.onclick=()=>{step--;showTrace()};next.onclick=()=>{step++;showTrace()};$('trace-controls').append(prev,el('span',` Step ${step} / ${inputs.length} `),next);const t=el('table');[['Input',inputs],['Expected / predicted left',v.expected??v.predicted_left],['Actual / left',v.actual??v.actual_outputs??v.actual_left],['Predicted right',v.predicted_right],['Actual right',v.actual_right]].forEach(([label,values])=>{if(!Array.isArray(values))return;const tr=el('tr');tr.append(el('th',label),el('td',step===0?'RESET':values[step-1]??'not observed'));t.append(tr)});$('trace-body').replaceChildren(t)}
    #|$('filter').oninput=()=>{page=0;render()};render();if(entries.length)select(entries[0]);
    #|const models=[['Baseline',data.model],['Inferred',data.inference?.learning?.model],['Left',data.left?.learning?.model],['Right',data.right?.learning?.model]].filter(x=>x[1]?.transitions);
    #|function stateGraph(m){const box=el('div'),select=el('select'),host=el('div');m.alphabet.forEach((s,i)=>{const o=el('option',s);o.value=i;select.append(o)});box.append(el('label','View transitions for input '),select,host);const ns='http://www.w3.org/2000/svg',node=(tag,attrs,text)=>{const n=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,String(v)));if(text!==undefined)n.textContent=text;return n};function draw(){host.replaceChildren();const n=m.transitions.length;if(n>64){host.append(el('p','Large model: use the complete transition table below.'));return}const svg=node('svg',{viewBox:'0 0 800 360',role:'img','aria-label':'Model transitions for selected input'}),pos=Array.from({length:n},(_,i)=>[400+260*Math.cos(2*Math.PI*i/n-Math.PI/2),180+125*Math.sin(2*Math.PI*i/n-Math.PI/2)]),col=Number(select.value);m.transitions.forEach((row,i)=>{const e=row[col],[x,y]=pos[i],[u,v]=pos[e.target];if(i===e.target){svg.append(node('path',{d:`M ${x-15} ${y-15} c -55 -65 85 -65 30 0`,fill:'none',stroke:'#6487a6','stroke-width':1.5}),node('text',{x:x,y:y-48,fill:'#99afc8','text-anchor':'middle','font-size':11},e.output))}else{svg.append(node('line',{x1:x,y1:y,x2:u,y2:v,stroke:'#38516a','stroke-width':1.5}),node('text',{x:(x+u)/2,y:(y+v)/2-6,fill:'#99afc8','text-anchor':'middle','font-size':11},`${e.output} → q${e.target}`))}});pos.forEach(([x,y],i)=>svg.append(node('circle',{cx:x,cy:y,r:21,fill:'#102a3b',stroke:i===m.initial?'#75f5de':'#6487a6','stroke-width':2}),node('text',{x,y:y+5,fill:'#e5edf7','text-anchor':'middle','font-size':13},`q${i}`)));host.append(svg)}select.onchange=draw;draw();return box}
    #|models.forEach(([name,m])=>{const d=el('details');d.open=models.length===1;d.append(el('summary',`${name}: ${m.transitions.length} states, initial q${m.initial}`),stateGraph(m));const t=el('table');m.transitions.forEach((row,state)=>row.forEach((edge,i)=>{const tr=el('tr');tr.append(el('td',`q${state}`),el('td',m.alphabet[i]),el('td',edge.output),el('td',`q${edge.target}`));t.append(tr)}));d.append(t);$('model-content').append(d)});if(!models.length)$('model-content').append(el('p','No model embedded in this report. Use saved model artifacts alongside the suite certificate.','muted'));
    #|$('download').onclick=()=>{const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=el('a');a.href=url;a.download='moonstatelens-evidence.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)};
    #|</script></html>
  page + evidence_escape(report.stringify(indent=2)) + tail
}

///|
/// CI consumes one testcase per original assertion plus an explicit failure
/// when evidence is incomplete. Unknown formats are rejected.
pub fn regression_junit(report : Json) -> String raise LensError {
  guard report
    is {
      "format": "moonstatelens.regression-run",
      "cases": Array(cases),
      "execution_complete": complete,
      "suite_evidence": { "generation_complete": generated, .. },
      ..
    } else {
    raise InvalidArgument("expected regression-run report")
  }
  let lines = []
  let mut failures = 0
  let mut skipped = 0
  for entry in cases {
    guard entry is { "case": id, "status": String(status), .. } else {
      raise InvalidArgument("invalid regression testcase")
    }
    lines.push(
      "<testcase classname=\"MoonStateLens.Regression\" name=\"case-" +
      evidence_escape(id.stringify()) +
      "\">",
    )
    match status {
      "passed" => ()
      "failed" => {
        failures += 1
        lines.push(
          "<failure message=\"baseline output mismatch\">" +
          evidence_escape(entry.stringify()) +
          "</failure>",
        )
      }
      "not-run" => {
        skipped += 1
        lines.push("<skipped message=\"not fully executed and rechecked\"/>")
      }
      _ => raise InvalidArgument("unknown regression testcase status")
    }
    lines.push("</testcase>")
  }
  let incomplete = complete != Json(true) || generated != Json(true)
  if incomplete {
    failures += 1
    lines.push(
      "<testcase classname=\"MoonStateLens.Evidence\" name=\"complete-evidence\"><failure message=\"incomplete generation or execution\"/></testcase>",
    )
  }
  let total = cases.length() + (if incomplete { 1 } else { 0 })
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<testsuite name=\"MoonStateLens\" tests=\"\{total}\" failures=\"\{failures}\" skipped=\"\{skipped}\">\n" +
  lines.join("\n") +
  "\n</testsuite>\n"
}
