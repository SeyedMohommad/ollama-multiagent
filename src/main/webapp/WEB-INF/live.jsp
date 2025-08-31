<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="com.fasterxml.jackson.databind.ObjectMapper" %>
<%@ page import="ai.multiagent.ollama_multiagent.core.Agent" %>
<%
    ObjectMapper __om = new ObjectMapper();
    String topicStr = String.valueOf(request.getAttribute("topic"));
    String topicJson = __om.writeValueAsString(topicStr);
    String roundsStr = String.valueOf(request.getAttribute("rounds"));
    @SuppressWarnings("unchecked")
    List<Agent> agents = (List<Agent>) request.getAttribute("agents");

    Map<String, Map<String, String>> info = new LinkedHashMap<>();
    if (agents != null) for (Agent a : agents) {
        Map<String,String> m = new LinkedHashMap<>();
        m.put("model", a.model());
        info.put(a.name(), m);
    }
    String agentsJson = __om.writeValueAsString(info);

    @SuppressWarnings("unchecked")
    List<String> selectedModels = (List<String>) request.getAttribute("selectedModels");
    if (selectedModels == null) selectedModels = java.util.List.of();
    String modelsJson = __om.writeValueAsString(selectedModels);
%>
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8"/>
    <title>Live Roundtable</title>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <style>
        :root{
            --bg:#f4f6fb;--card:#ffffff;--text:#0f172a;--muted:#64748b;--border:#e5e7eb;
            --brand:#2563eb;--ok:#10b981;--warn:#f59e0b;--err:#ef4444;--shadow:0 10px 30px rgba(15,23,42,.08);
            --bubble:#f8fafc;--bubble2:#eef2ff;
        }
        @media (prefers-color-scheme:dark){
            :root{--bg:#0b1220;--card:#0f172a;--text:#e5e7eb;--muted:#94a3b8;--border:#1e293b;--shadow:0 10px 30px rgba(0,0,0,.35);--bubble:#0f1b30;--bubble2:#12213a}
        }
        *{box-sizing:border-box}
        html,body{height:100%}
        body{margin:0;background:radial-gradient(1200px 600px at 20% -10%, rgba(37,99,235,.12), transparent 50%), var(--bg); color:var(--text); font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif}

        .container{max-width:980px;margin:0 auto;height:100vh;display:grid;grid-template-rows:auto 1fr auto}
        .header{position:sticky;top:0;z-index:3;backdrop-filter:blur(10px);background:linear-gradient(180deg,rgba(255,255,255,.7),rgba(255,255,255,.4));border-bottom:1px solid var(--border)}
        @media (prefers-color-scheme:dark){.header{background:linear-gradient(180deg,rgba(15,23,42,.65),rgba(15,23,42,.35))}}
        .hwrap{display:flex;gap:14px;align-items:center;padding:12px 16px}
        .back{color:var(--muted);text-decoration:none;font-size:14px;padding:6px 10px;border-radius:10px;border:1px solid var(--border)}
        .ttl{font-weight:800}
        .sub{color:var(--muted);font-size:13px;margin-top:2px}
        .members{margin-top:6px;display:flex;gap:8px;flex-wrap:wrap}
        .pill{background:var(--card);border:1px solid var(--border);border-radius:999px;padding:4px 10px;font-size:12px;box-shadow:var(--shadow)}
        code{font-family:ui-monospace,Consolas,monospace}

        .status{display:flex;align-items:center;gap:8px;padding:8px 16px;background:var(--card);border-bottom:1px solid var(--border)}
        .dot{width:10px;height:10px;border-radius:999px;background:var(--warn);box-shadow:0 0 0 4px rgba(245,158,11,.12)}
        .dot.ok{background:var(--ok);box-shadow:0 0 0 4px rgba(16,185,129,.12)}
        .dot.err{background:var(--err);box-shadow:0 0 0 4px rgba(239,68,68,.12)}
        .stat-txt{font-size:13px;color:var(--muted)}

        .chat{padding:16px;overflow-y:auto;display:flex;flex-direction:column;gap:14px}
        .msg{display:flex;gap:10px;align-items:flex-start}
        .avatar{width:38px;height:38px;border-radius:50%;color:#fff;display:grid;place-items:center;font-weight:800;box-shadow:var(--shadow);user-select:none}
        .content{display:flex;flex-direction:column;gap:6px;max-width:82%}
        .meta{font-size:12px;color:var(--muted);display:flex;gap:8px;flex-wrap:wrap;align-items:center}
        .who{font-weight:800;background:var(--bubble2);border:1px solid var(--border);border-radius:8px;padding:2px 8px}
        .reply{background:#e5e7eb;color:#374151;border-radius:8px;padding:2px 8px}
        @media (prefers-color-scheme:dark){.reply{background:#172033;color:#cbd5e1}}
        .round{opacity:.85}
        .bubble{position:relative;background:var(--bubble);border:1px solid var(--border);border-left:4px solid var(--border);border-radius:16px;padding:12px 14px;line-height:1.7;white-space:pre-wrap;word-break:break-word;box-shadow:var(--shadow)}
        .msg[data-accent] .bubble{border-left-color:var(--accent)}
        .bubble:after{content:"";position:absolute;left:10px;top:-6px;border:8px solid transparent;border-bottom-color:var(--bubble)}
        .bubble.done{background:linear-gradient(180deg,rgba(16,185,129,.12),transparent);border-color:#bbf7d0}

        .foot{background:var(--card);border-top:1px solid var(--border);padding:10px 16px;color:var(--muted);font-size:12px;display:flex;justify-content:space-between;align-items:center}
        .btn-sm{appearance:none;border:1px solid var(--border);background:transparent;color:var(--muted);padding:6px 10px;border-radius:10px;cursor:pointer}

        .scrollToEnd{position:fixed;right:24px;bottom:24px;z-index:5;padding:10px 12px;border-radius:12px;background:var(--card);border:1px solid var(--border);box-shadow:var(--shadow);cursor:pointer;display:none}
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="hwrap">
            <a class="back" href="/">← Back</a>
            <div>
                <div class="ttl">Live Multi-LLM Roundtable</div>
                <div class="sub">Topic: <span id="topicView"></span> • Rounds: <%= roundsStr %></div>
                <div class="members">
                    <%
                        if (agents != null) for (Agent a : agents) {
                    %>
                    <span class="pill"><b><%= a.name() %></b> &nbsp;→&nbsp; <code><%= a.model() %></code></span>
                    <% } %>
                </div>
            </div>
        </div>
        <div class="status">
            <div id="dot" class="dot"></div>
            <div class="stat-txt" id="statTxt">Connecting…</div>
            <div style="margin-left:auto" class="stat-txt" id="progressTxt"></div>
        </div>
    </div>

    <div class="chat" id="chat"></div>

    <div class="foot">
        <div>Messages stream live — one bubble per speaker per turn.</div>
        <button class="btn-sm" id="copyAll">Copy transcript</button>
    </div>
</div>

<button class="scrollToEnd" id="toEnd">↓ New messages</button>

<script>
    // Inputs from server
    const TOPIC  = <%= topicJson %>;
    const ROUNDS = parseInt(<%= roundsStr %>,10) || 1;
    const AGENTS_INFO = <%= agentsJson %>;   // { "Name": { model:"..." }, ... }
    const MODELS = <%= modelsJson %>;

    document.getElementById("topicView").textContent = TOPIC || "—";

    const chat = document.getElementById("chat");
    const dot = document.getElementById("dot");
    const statTxt = document.getElementById("statTxt");
    const progressTxt = document.getElementById("progressTxt");
    const toEndBtn = document.getElementById("toEnd");

    const TOTAL = ROUNDS * Object.keys(AGENTS_INFO||{}).length;
    let doneCount = 0;

    const scrollBottom = (force=false)=>{
        const nearBottom = chat.scrollHeight - chat.scrollTop - chat.clientHeight < 80;
        if (force || nearBottom) chat.scrollTop = chat.scrollHeight;
        toEndBtn.style.display = nearBottom ? "none" : "block";
    };
    chat.addEventListener('scroll', ()=>scrollBottom(false));
    toEndBtn.addEventListener('click', ()=>scrollBottom(true));

    const initials = (name) => (name||"A").split(/\s+/).map(s=>s[0]).join("").slice(0,2).toUpperCase();
    const colorCache = Object.create(null);
    const colorFor = (name) => {
        if (colorCache[name]) return colorCache[name];
        let h=0; for (let i=0;i<name.length;i++) h=(h*31+name.charCodeAt(i))%360;
        const c=`hsl(${h} 70% 50%)`; colorCache[name]=c; return c;
    };

    const currentBubbleByAgent = Object.create(null);

    function createMessage(agentName, replyTo, round){
        const wrap = document.createElement("div");
        wrap.className = "msg";
        const accent = colorFor(agentName);
        wrap.dataset.accent = "1";
        wrap.style.setProperty("--accent", accent);

        const av = document.createElement("div");
        av.className = "avatar";
        av.style.background = `linear-gradient(135deg, ${accent}, rgba(255,255,255,.2))`;
        av.textContent = initials(agentName);

        const content = document.createElement("div");
        content.className = "content";

        const meta = document.createElement("div");
        meta.className = "meta";
        const who = document.createElement("span");
        who.className = "who"; who.textContent = agentName;
        const model = document.createElement("span");
        model.innerHTML = '<code>' + ((AGENTS_INFO && AGENTS_INFO[agentName] && AGENTS_INFO[agentName].model)
            ? AGENTS_INFO[agentName].model
            : '') + '</code>';

        const rnd = document.createElement("span");
        rnd.className = "round"; rnd.textContent = `Round ${round}`;
        meta.appendChild(who); meta.appendChild(model);
        if (replyTo){ const rp=document.createElement("span"); rp.className="reply"; rp.textContent=`↶ ${replyTo}`; meta.appendChild(rp); }
        meta.appendChild(rnd);

        const bubble = document.createElement("div");
        bubble.className = "bubble";
        bubble.textContent = "";

        content.appendChild(meta);
        content.appendChild(bubble);

        wrap.appendChild(av);
        wrap.appendChild(content);

        chat.appendChild(wrap);
        currentBubbleByAgent[agentName] = bubble;
        scrollBottom(true);
    }

    // Build SSE URL
    const params = new URLSearchParams({ topic: TOPIC, rounds: String(ROUNDS) });
    (MODELS||[]).forEach(m => params.append("models", m));
    const es = new EventSource("/api/stream?" + params.toString());

    es.addEventListener("open", ()=>{ dot.className="dot ok"; statTxt.textContent="Streaming…"; });
    es.addEventListener("start", (e)=>{
        const d = JSON.parse(e.data);
        createMessage(d.agentName, d.replyTo, d.round || 1);
        progressTxt.textContent = `${doneCount}/${TOTAL}`;
    });
    es.addEventListener("delta", (e)=>{
        const d = JSON.parse(e.data);
        const bubble = currentBubbleByAgent[d.agentName];
        if (!bubble) return;
        if (d.delta) { bubble.textContent += d.delta; }
        scrollBottom(false);
    });
    es.addEventListener("done", (e)=>{
        const d = JSON.parse(e.data);
        const bubble = currentBubbleByAgent[d.agentName];
        if (bubble){
            const txt = bubble.textContent;
            const cut = txt.indexOf("[END]");
            bubble.textContent = (cut>=0? txt.slice(0,cut) : txt).trim();
            bubble.classList.add("done");
            delete currentBubbleByAgent[d.agentName];
        }
        doneCount++; progressTxt.textContent = `${doneCount}/${TOTAL}`;
        if (doneCount >= TOTAL){ statTxt.textContent = "✓ All rounds complete"; dot.className="dot ok"; }
        scrollBottom(true);
    });
    es.onerror = ()=>{ dot.className="dot err"; statTxt.textContent="Connection lost (auto-retry)…"; };

    // Copy transcript
    document.getElementById('copyAll').addEventListener('click', ()=>{
        const blocks = Array.from(document.querySelectorAll('.msg')).map(m=>{
            const who = m.querySelector('.who')?.textContent || "";
            const text = m.querySelector('.bubble')?.textContent || "";
            return `### ${who}\n${text}`;
        }).join("\n\n");
        navigator.clipboard.writeText(blocks).then(()=>{ statTxt.textContent="Copied transcript"; setTimeout(()=>statTxt.textContent="Streaming…",1500); });
    });
</script>
</body>
</html>
