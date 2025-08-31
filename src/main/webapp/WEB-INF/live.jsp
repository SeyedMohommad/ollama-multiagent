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

    // Build a simple { name: { model: "..." } } map for JS
    Map<String, Map<String, String>> info = new LinkedHashMap<>();
    if (agents != null) {
        for (Agent a : agents) {
            Map<String,String> m = new LinkedHashMap<>();
            m.put("model", a.model());
            info.put(a.name(), m);
        }
    }
    String agentsJson = __om.writeValueAsString(info);

    // Selected models to pass along to SSE query (?models=...&models=...)
    @SuppressWarnings("unchecked")
    List<String> selectedModels = (List<String>) request.getAttribute("selectedModels");
    if (selectedModels == null) selectedModels = java.util.List.of();
    String modelsJson = __om.writeValueAsString(selectedModels);
%>
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8"/>
    <title>Live Multi-LLM Roundtable</title>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <style>
        :root {
            --bg:#f6f7f9; --card:#fff; --text:#1f2937; --muted:#6b7280; --border:#e5e7eb;
            --bubble:#f8fafc; --bubble-strong:#eef2f7;
        }
        *{box-sizing:border-box}
        html,body{height:100%}
        body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif}
        .container{max-width:900px;margin:0 auto;display:grid;grid-template-rows:auto 1fr auto;height:100vh}
        .header{padding:12px 16px;background:var(--card);border-bottom:1px solid var(--border);display:flex;gap:12px;align-items:flex-start;position:sticky;top:0;z-index:2}
        .back{color:var(--muted);text-decoration:none;font-size:14px;padding-top:4px}
        .title{font-weight:700}
        .sub{color:var(--muted);font-size:13px}
        .topic{font-weight:600}
        .members{margin-top:4px;display:flex;gap:6px;flex-wrap:wrap}
        .pill{background:#eef2f7;border:1px solid var(--border);border-radius:999px;padding:2px 8px;font-size:12px}

        .hint{margin:10px auto;padding:6px 10px;background:#fff;border:1px dashed var(--border);border-radius:10px;font-size:12px;color:var(--muted);width:fit-content}

        .chat{padding:12px;overflow-y:auto;scroll-behavior:smooth;display:flex;flex-direction:column;gap:10px}
        .msg{display:flex;gap:10px;align-items:flex-start}
        .avatar{width:36px;height:36px;border-radius:50%;color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:14px;box-shadow:0 1px 2px rgba(15,23,42,.08);user-select:none}
        .content{display:flex;flex-direction:column;gap:4px;max-width:85%}
        .name{font-size:12px;color:var(--muted);font-weight:700;display:flex;gap:6px;flex-wrap:wrap;align-items:center}
        .who{padding:2px 6px;border-radius:6px;border:1px solid var(--border);background:var(--bubble-strong)}
        .model{color:var(--muted);font-family:ui-monospace,monospace}
        .reply{color:#374151;background:#e5e7eb;border-radius:6px;padding:1px 6px}
        .round{color:#6b7280}
        .bubble{background:var(--bubble);border:1px solid var(--border);border-left:4px solid var(--border);border-radius:14px;padding:10px 12px;line-height:1.7;white-space:pre-wrap;word-break:break-word}
        .msg[data-accent] .bubble{border-left-color:var(--accent)}
        .bubble.done{background:#ecfdf5;border-color:#d1fae5}
        .foot{padding:10px 14px;background:var(--card);border-top:1px solid var(--border);font-size:12px;color:var(--muted)}
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <a class="back" href="/">← Back</a>
        <div>
            <div class="title">Live Multi-LLM Roundtable (Streaming)</div>
            <div class="sub">Topic: <span class="topic" id="topicView"></span> • Rounds: <%= roundsStr %></div>
            <div class="members">
                <%
                    if (agents != null) for (Agent a : agents) {
                %>
                <span class="pill"><%= a.name() %> → <code><%= a.model() %></code></span>
                <% } %>
            </div>
        </div>
    </div>

    <div class="hint" id="hint">Waiting for the first message…</div>
    <div class="chat" id="chat"></div>
    <div class="foot">Messages stream live, one bubble per speaker per turn — like a group chat.</div>
</div>

<script>
    // Inputs from server
    const TOPIC       = <%= topicJson %>;
    const ROUNDS      = <%= roundsStr %>;
    const AGENTS_INFO = <%= agentsJson %>;   // { "Llama1B": { model:"llama3.2:1b" }, ... }
    const MODELS      = <%= modelsJson %>;   // ["llama3.2:1b","qwen2.5:1.5b-instruct", ...]

    document.getElementById("topicView").textContent = TOPIC || "—";

    const chat = document.getElementById("chat");
    const hint = document.getElementById("hint");
    const scrollBottom = () => chat.scrollTop = chat.scrollHeight;

    const initials = (name) => {
        const p = (name||"").trim().split(/\s+/);
        return ((p[0]?.[0]||"") + (p[1]?.[0]||"")).toUpperCase() || (name?.[0]||"A").toUpperCase();
    };
    const colorCache = Object.create(null);
    const colorFor = (name) => {
        if (colorCache[name]) return colorCache[name];
        let h=0; for (let i=0;i<name.length;i++) h=(h*31+name.charCodeAt(i))%360;
        const c=`hsl(${h} 70% 45%)`; colorCache[name]=c; return c;
    };

    const currentBubbleByAgent = Object.create(null);

    function createMessage(agentName, replyTo, round){
        hint.style.display = "none";
        const msg  = document.createElement("div");
        msg.className = "msg";
        const accent = colorFor(agentName);
        msg.dataset.accent = "1";
        msg.style.setProperty("--accent", accent);

        const av = document.createElement("div");
        av.className = "avatar";
        av.textContent = initials(agentName);
        av.style.background = accent;

        const content = document.createElement("div");
        content.className = "content";

        const name = document.createElement("div");
        name.className = "name";
        const who = document.createElement("span");
        who.className = "who";
        who.textContent = agentName;
        const model = document.createElement("code");
        model.className = "model";
        model.textContent = AGENTS_INFO?.[agentName]?.model || "";
        const roundEl = document.createElement("span");
        roundEl.className = "round";
        roundEl.textContent = `— Round ${round}`;
        name.appendChild(who);
        if (model.textContent) name.appendChild(model);
        if (replyTo) {
            const rp = document.createElement("span");
            rp.className = "reply";
            rp.textContent = `↶ reply to ${replyTo}`;
            name.appendChild(rp);
        }
        name.appendChild(roundEl);

        const bubble = document.createElement("div");
        bubble.className = "bubble";
        bubble.textContent = "";

        content.appendChild(name);
        content.appendChild(bubble);

        msg.appendChild(av);
        msg.appendChild(content);

        chat.appendChild(msg);

        currentBubbleByAgent[agentName] = bubble;
        scrollBottom();
    }

    // SSE params: ?topic=...&rounds=...&models=...&models=...
    const params = new URLSearchParams({ topic: TOPIC, rounds: ROUNDS });
    (MODELS || []).forEach(m => params.append("models", m));

    const es = new EventSource("/api/stream?" + params.toString());

    es.addEventListener("start", (e)=>{
        const d = JSON.parse(e.data); // {agentName, round, replyTo, phase:"start"}
        createMessage(d.agentName, d.replyTo, d.round || 1);
    });

    es.addEventListener("delta", (e)=>{
        const d = JSON.parse(e.data); // {agentName, delta, ...}
        const bubble = currentBubbleByAgent[d.agentName];
        if (!bubble) return;
        if (d.delta){
            bubble.textContent += d.delta;
            scrollBottom();
        }
    });

    es.addEventListener("done", (e)=>{
        const d = JSON.parse(e.data);
        const bubble = currentBubbleByAgent[d.agentName];
        if (bubble){
            const txt = bubble.textContent;
            const i = txt.indexOf("[END]");
            bubble.textContent = (i >= 0 ? txt.substring(0,i) : txt).trim();
            bubble.classList.add("done");
            delete currentBubbleByAgent[d.agentName];
        }
        scrollBottom();
    });

    es.onerror = ()=>{ if (es.readyState === EventSource.CLOSED) console.log("SSE closed"); };
</script>
</body>
</html>
