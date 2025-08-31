<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="ai.multiagent.ollama_multiagent.core.TurnMessage" %>
<%@ page import="ai.multiagent.ollama_multiagent.core.Agent" %>
<html>
<head>
    <title>نتیجه گفتگو</title>
    <style>
        body { font-family: sans-serif; margin: 2rem; }
        .meta { margin-bottom: 1rem; }
        .pill { display: inline-block; padding: .2rem .6rem; margin: .2rem; border-radius: 999px; background: #f0f0f0; }
        .msg { border: 1px solid #e5e5e5; border-radius: 12px; padding: 1rem; margin: .8rem 0; }
        .agent { font-weight: bold; margin-bottom: .4rem; }
        pre { white-space: pre-wrap; margin: 0; }
        a { text-decoration: none; }
    </style>
</head>
<body>
<a href="/">← بازگشت</a>
<h1>خلاصه‌ی گفتگو</h1>

<div class="meta">
    <p><b>موضوع:</b> ${topic}</p>
    <p><b>دورها:</b> ${rounds}</p>
    <p><b>عامل‌ها:</b>
        <%
            List<Agent> agents = (List<Agent>) request.getAttribute("agents");
            if (agents != null) {
                for (Agent a : agents) { %>
        <span class="pill"><%= a.name() %> → <%= a.model() %></span>
        <% } } %>
    </p>
</div>

<%
    List<TurnMessage> messages = (List<TurnMessage>) request.getAttribute("messages");
    if (messages != null) {
        for (TurnMessage m : messages) {
%>
<div class="msg">
    <div class="agent"><%= m.agentName() %></div>
    <pre><%= m.text() %></pre>
</div>
<%
        }
    }
%>
</body>
</html>
