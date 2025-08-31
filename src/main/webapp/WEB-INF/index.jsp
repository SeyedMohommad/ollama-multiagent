<%@ page contentType="text/html;charset=UTF-8" %>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8"/>
    <title>Multi-LLM (Ollama)</title>
    <style>
        body { font-family: sans-serif; margin: 2rem; }
        form { display: grid; gap: 1rem; max-width: 720px; }
        input[type="text"], input[type="number"] { padding: .6rem .8rem; width: 100%; }
        .agents { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .5rem 1.5rem; }
        button { padding: .6rem 1rem; font-size: 1rem; }
        small { color: #666; }
        label { display: grid; gap: .4rem; }
        fieldset { border: 1px solid #ddd; padding: 1rem; border-radius: .5rem; }
        legend { padding: 0 .5rem; color: #333; }
    </style>
</head>
<body>
<h1>Multi-LLM Conversation with Ollama (Lightweight)</h1>

<form method="get" action="/live">
    <label>
        Topic:
        <input name="topic" required placeholder="e.g., Key challenges of onboarding in our app"/>
    </label>

    <label>
        Rounds:
        <input name="rounds" type="number" value="2" min="1" max="6"/>
    </label>

    <fieldset>
        <legend>Models</legend>
        <div class="agents">
            <label><input type="checkbox" name="useLlama1B" checked> llama3.2:1b</label>
            <label><input type="checkbox" name="useQwen15B" checked> qwen2.5:1.5b-instruct</label>
            <label><input type="checkbox" name="usePhi3Mini"> phi3:mini</label>
            <label><input type="checkbox" name="usePhi4Mini"> phi4-mini:latest</label>
        </div>
        <small>Tip: start with 1–2 lightweight models if your machine is resource-constrained.</small>
    </fieldset>

    <button type="submit">Start Streaming</button>
</form>

</body>
</html>
