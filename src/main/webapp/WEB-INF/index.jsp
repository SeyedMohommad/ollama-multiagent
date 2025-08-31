<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="ai.multiagent.ollama_multiagent.ollama.dto.OllamaModelTag" %>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8"/>
    <title>Multi-LLM (Ollama)</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; }
        form { display: grid; gap: 1rem; max-width: 860px; }
        input[type="text"], input[type="number"] { padding: .6rem .8rem; width: 100%; }
        fieldset { border: 1px solid #ddd; border-radius: .6rem; padding: 1rem; }
        legend { padding: 0 .5rem; font-weight: 700; }
        .grid { display: grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap: .5rem 1.5rem; }
        .row { display: flex; gap: .5rem; align-items: center; }
        .dim { color: #666; font-size: .9rem; }
        .bar { display:flex; gap:.5rem; align-items:center; }
        button { padding: .6rem 1rem; font-size: 1rem; }
        .tip { color:#555; font-size:.9rem; }
        code { background:#f3f4f6; padding:.1rem .3rem; border-radius:.3rem; }
    </style>
</head>
<body>
<h1>Multi-LLM Conversation with Ollama (Lightweight)</h1>

<form method="get" action="/live">
    <label>
        Topic:
        <input name="topic" required placeholder="e.g., Key challenges of onboarding"/>
    </label>

    <label>
        Rounds:
        <input name="rounds" type="number" value="2" min="1" max="6"/>
    </label>

    <fieldset>
        <legend>Models detected from Ollama</legend>
        <div class="bar">
            <span class="tip">Pick 1–3 lightweight models. You can also <a href="#" id="pickLight">auto-pick light ones</a>.</span>
        </div>
        <div class="grid" id="modelsGrid">
            <%
                List<OllamaModelTag> list = (List<OllamaModelTag>) request.getAttribute("models");
                if (list == null || list.isEmpty()) {
            %>
            <div class="dim">No models found. Make sure <code>ollama serve</code> is running and models are pulled (e.g., <code>ollama pull llama3.2:1b</code>).</div>
            <%
            } else {
                for (OllamaModelTag t : list) {
                    String name = t.name;
                    long size = t.size;
                    String human = (size >= (1L<<30))
                            ? String.format("%.1f GB", size / (double)(1L<<30))
                            : String.format("%.0f MB", size / (double)(1L<<20));
                    String params = (t.details != null && t.details.parameter_size != null) ? t.details.parameter_size : "";
                    String family = (t.details != null && t.details.family != null) ? t.details.family : "";
            %>
            <label class="row">
                <input type="checkbox" name="models" value="<%= name %>" data-size="<%= size %>"/>
                <span><strong><%= name %></strong>
            <span class="dim">• <%= human %><%= params.isEmpty() ? "" : " • " + params %><%= family.isEmpty() ? "" : " • " + family %></span>
          </span>
            </label>
            <%
                    }
                }
            %>
        </div>
    </fieldset>

    <button type="submit">Start Streaming</button>
</form>

<script>
    // Auto-pick lightweight models (<= 2.6 GB), up to 3
    document.getElementById('pickLight')?.addEventListener('click', (e)=>{
        e.preventDefault();
        const boxes = Array.from(document.querySelectorAll('input[name="models"]'));
        boxes.forEach(b => b.checked = false);
        const threshold = 2.6 * (1<<30); // ~2.6 GB
        let picked = 0;
        for (const b of boxes.sort((a,b)=> (+a.dataset.size) - (+b.dataset.size))) {
            if (+b.dataset.size <= threshold) {
                b.checked = true;
                if (++picked >= 3) break;
            }
        }
    });
</script>

</body>
</html>
