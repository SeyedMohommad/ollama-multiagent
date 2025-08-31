<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="ai.multiagent.ollama_multiagent.ollama.dto.OllamaModelTag" %>
<%
    @SuppressWarnings("unchecked")
    List<OllamaModelTag> list = (List<OllamaModelTag>) request.getAttribute("models");
%>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8"/>
    <title>Ollama Roundtable · Multi-LLM</title>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <style>
        :root{
            --bg:#f6f7f9;--card:#fff;--text:#0f172a;--muted:#64748b;--border:#e5e7eb;--brand:#2563eb;
            --chip:#eef2ff;--chip-text:#4338ca;--shadow:0 8px 24px rgba(15,23,42,.08);
            --ok:#10b981;--warn:#f59e0b;--danger:#ef4444;
        }
        @media (prefers-color-scheme:dark){
            :root{--bg:#0b1220;--card:#0f172a;--text:#e5e7eb;--muted:#94a3b8;--border:#1e293b;--chip:#0b2a57;--chip-text:#93c5fd;--shadow:0 8px 24px rgba(0,0,0,.35)}
            code{background:#0b1930!important}
        }
        *{box-sizing:border-box}
        body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif}
        .wrap{max-width:1000px;margin:0 auto;padding:24px}
        .hdr{display:flex;align-items:center;gap:12px;margin-bottom:18px}
        .logo{width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg,#60a5fa,#2563eb);box-shadow:var(--shadow)}
        h1{margin:0;font-size:22px}
        .sub{color:var(--muted);font-size:13px;margin-top:2px}

        form.card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:18px;box-shadow:var(--shadow);display:grid;gap:16px}
        label.lbl{display:grid;gap:6px}
        input[type="text"],input[type="number"],input[type="search"]{
            padding:.7rem .85rem;border:1px solid var(--border);background:transparent;color:var(--text);
            border-radius:10px;outline:none;box-shadow:inset 0 1px 0 rgba(255,255,255,.04)
        }
        .row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
        .toolbar{display:flex;gap:10px;flex-wrap:wrap;align-items:center;justify-content:space-between}
        .chips{display:flex;gap:8px;flex-wrap:wrap}
        .chip{padding:6px 10px;border-radius:999px;background:var(--chip);color:var(--chip-text);font-size:12px;border:1px solid var(--border);cursor:pointer;user-select:none}
        .chip:hover{filter:brightness(.98)}
        .muted{color:var(--muted)}
        .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}

        .card-mdl{position:relative;display:flex;gap:10px;padding:12px;border:1px solid var(--border);border-radius:14px;background:linear-gradient(180deg,rgba(255,255,255,.04),transparent);align-items:flex-start}
        .card-mdl input{position:absolute;inset:0;opacity:0;cursor:pointer}
        .tick{position:absolute;top:10px;right:10px;width:20px;height:20px;border-radius:6px;border:1px solid var(--border);background:#fff;display:grid;place-items:center;color:#fff;font-size:14px}
        @media (prefers-color-scheme:dark){.tick{background:#0b1220}}
        .meta{display:flex;flex-direction:column;gap:4px}
        .mdl-name{font-weight:700}
        .badges{display:flex;gap:6px;flex-wrap:wrap}
        .badge{font-size:11px;padding:2px 6px;border-radius:999px;border:1px solid var(--border);color:var(--muted)}
        .fam-llama{background:rgba(59,130,246,.1)} .fam-qwen2{background:rgba(16,185,129,.12)}
        .fam-phi3,.fam-phi{background:rgba(244,114,182,.12)}
        .fam-phi3 .badge,.fam-phi .badge{color:#be185d}

        .selected{outline:2px solid var(--brand);box-shadow:0 0 0 4px rgba(37,99,235,.12) inset}
        .selected .tick{background:var(--brand);border-color:transparent}
        .selected .tick:before{content:"✓"}

        .fbar{display:flex;gap:10px;align-items:center;justify-content:space-between;margin-top:6px}
        .btn{appearance:none;border:none;background:linear-gradient(135deg,#3b82f6,#2563eb);color:#fff;padding:.8rem 1.1rem;border-radius:12px;font-weight:700;cursor:pointer;box-shadow:var(--shadow)}
        .btn:disabled{opacity:.5;cursor:not-allowed}
        .help{font-size:12px;color:var(--muted)}

        code{background:#eef2f7;padding:.1rem .35rem;border-radius:.35rem}
    </style>
</head>
<body>
<div class="wrap">
    <div class="hdr">
        <div class="logo"></div>
        <div>
            <h1>Ollama Roundtable · Multi-LLM</h1>
            <div class="sub">Pick lightweight local models and stream a Telegram-style roundtable.</div>
        </div>
    </div>

    <form class="card" method="get" action="/live">
        <div class="row">
            <label class="lbl" style="flex:1 1 420px">
                Topic
                <input name="topic" required placeholder="e.g., Key challenges of onboarding"/>
            </label>
            <label class="lbl" style="width:160px">
                Rounds
                <input name="rounds" type="number" value="2" min="1" max="6"/>
            </label>
        </div>

        <div class="toolbar">
            <div class="row">
                <input id="q" type="search" placeholder="Search models (name/family/params)"/>
                <div class="chips">
                    <span class="chip" id="pickLight">Auto-pick light (≤2.6GB)</span>
                    <span class="chip" id="pickNone">Clear</span>
                    <span class="chip" id="sortSize">Sort by size</span>
                    <span class="chip" id="sortName">Sort by name</span>
                </div>
            </div>
            <div class="muted" id="selInfo">0 selected (recommended: ≤3)</div>
        </div>

        <div class="grid" id="modelsGrid">
            <%
                if (list == null || list.isEmpty()) {
            %>
            <div class="muted">No models found. Ensure <code>ollama serve</code> is running and models are pulled (e.g., <code>ollama pull llama3.2:1b</code>).</div>
            <%
            } else {
                for (OllamaModelTag t : list) {
                    String name = t.name;
                    long size = t.size;
                    String human = (size >= (1L<<30)) ? String.format("%.1f GB", size / (double)(1L<<30))
                            : String.format("%.0f MB", size / (double)(1L<<20));
                    String params = (t.details != null && t.details.parameter_size != null) ? t.details.parameter_size : "";
                    String family = (t.details != null && t.details.family != null) ? t.details.family : "";
            %>
            <label class="card-mdl" data-name="<%= name %>" data-family="<%= family %>" data-params="<%= params %>">
                <input type="checkbox" name="models" value="<%= name %>" data-size="<%= size %>"/>
                <div class="tick"></div>
                <div class="meta">
                    <div class="mdl-name"><%= name %></div>
                    <div class="badges">
                        <span class="badge"><%= human %></span>
                        <% if (!params.isEmpty()) { %><span class="badge"><%= params %></span><% } %>
                        <% if (!family.isEmpty()) { %><span class="badge fam-<%= family %>"><%= family %></span><% } %>
                    </div>
                    <div class="help">Click to select. Lightweight devices: pick up to 3.</div>
                </div>
            </label>
            <%
                    }
                }
            %>
        </div>

        <div class="fbar">
            <div class="help">Tip: Start small (e.g., <code>llama3.2:1b</code> + <code>qwen2.5:1.5b-instruct</code>), then add more.</div>
            <button class="btn" type="submit" id="goBtn">Start Streaming</button>
        </div>
    </form>
</div>

<script>
    const grid = document.getElementById('modelsGrid');
    const search = document.getElementById('q');
    const selInfo = document.getElementById('selInfo');
    const goBtn = document.getElementById('goBtn');

    const cards = Array.from(grid.querySelectorAll('.card-mdl'));
    const inputs = cards.map(c => c.querySelector('input[name="models"]'));

    const updateSelected = ()=>{
        let n = inputs.filter(i=>i.checked).length;
        selInfo.textContent = `${n} selected (recommended: ≤3)`;
        inputs.forEach(i=> i.closest('.card-mdl').classList.toggle('selected', i.checked));
    };

    grid.addEventListener('click', (e)=>{
        const card = e.target.closest('.card-mdl');
        if (!card) return;
        const input = card.querySelector('input[name="models"]');
        if (e.target !== input) { input.checked = !input.checked; }
        updateSelected();
    });

    document.getElementById('pickLight')?.addEventListener('click', (e)=>{
        e.preventDefault();
        inputs.forEach(b => b.checked = false);
        const threshold = 2.6 * (1<<30);
        let picked = 0;
        inputs.sort((a,b)=> (+a.dataset.size) - (+b.dataset.size))
            .forEach(b => { if (+b.dataset.size <= threshold && picked < 3) { b.checked = true; picked++; }});
        updateSelected();
    });
    document.getElementById('pickNone')?.addEventListener('click', (e)=>{ e.preventDefault(); inputs.forEach(b=>b.checked=false); updateSelected(); });

    let sizeAsc = true, nameAsc = true;
    document.getElementById('sortSize')?.addEventListener('click',(e)=>{
        e.preventDefault();
        const by = (a,b)=> (sizeAsc ? (+a.dataset.size - +b.dataset.size) : (+b.dataset.size - +a.dataset.size));
        const sorted = Array.from(cards).sort((A,B)=> by(A.querySelector('input'), B.querySelector('input')));
        sizeAsc = !sizeAsc;
        sorted.forEach(c => grid.appendChild(c));
    });
    document.getElementById('sortName')?.addEventListener('click',(e)=>{
        e.preventDefault();
        const sorted = Array.from(cards).sort((A,B)=>{
            const an = (A.dataset.name||"").toLowerCase(), bn=(B.dataset.name||"").toLowerCase();
            return nameAsc ? an.localeCompare(bn) : bn.localeCompare(an);
        });
        nameAsc = !nameAsc;
        sorted.forEach(c => grid.appendChild(c));
    });

    const filter = ()=>{
        const q = (search.value||"").toLowerCase().trim();
        cards.forEach(c=>{
            const hit = [c.dataset.name, c.dataset.family, c.dataset.params].some(v => (v||"").toLowerCase().includes(q));
            c.style.display = hit ? "" : "none";
        });
    };
    search.addEventListener('input', filter);
    updateSelected();
</script>
</body>
</html>
