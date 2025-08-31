

# Ollama Multi-Agent Orchestrator (Lightweight)

A minimal Java/Spring + JSP web app that lets **multiple small LLMs (Ollama)** hold a **round-table chat**.
Messages stream live with **SSE** (Server-Sent Events) and render like a **group chat UI**.

> Built for low-resource setups (CPU-only). Works great with `llama3.2:1b`, `qwen2.5:1.5b-instruct`, `phi3:mini`, `phi4-mini:latest`.

---

## ✨ Features

* **Auto-discover models** from a local Ollama daemon (`/api/tags`) and pick which ones to include.
* **Round-table orchestration**: agents take turns; each sees the transcript so far and can “reply to” the previous speaker.
* **Live streaming** with **SSE** — one chat bubble per agent per turn (like Telegram/Slack).
* **Lightweight UI** (JSP + vanilla JS), color-coded avatars, readable bubbles.
* Designed for **tiny models** and **CPU-only** laptops.

---

## 🧱 Tech Stack

* **Java 21**, **Spring Boot 3** (Web + Reactive), **JSP**
* **Project Reactor** (Flux) for streaming pipelines
* **Ollama** HTTP API (`/api/tags`, `/api/generate?stream=true`)
* **SSE** (Server-Sent Events) to the browser

---

## 📦 Project Coordinates

* **Group:** `ai.multiagent`
* **Artifact:** `ollama-multiagent`
* **Name:** `Ollama Multi-Agent Orchestrator (Lightweight)`

---

## 🚀 Quick Start

### 1) Install & run Ollama

```bash
# macOS (example)
brew install ollama

# start the daemon (default: http://127.0.0.1:11434)
ollama serve
```

### 2) Pull a few small models

```bash
ollama pull llama3.2:1b
ollama pull qwen2.5:1.5b-instruct
ollama pull phi3:mini
ollama pull phi4-mini:latest
```

### 3) Run the app

```bash
# Set the Ollama base URL if you changed it; default works fine
export OLLAMA_BASE_URL=http://127.0.0.1:11434

# Run
./mvnw spring-boot:run
# or build a jar:
./mvnw -DskipTests package
java -jar target/ollama-multiagent-*.jar
```

Open: `http://localhost:8080`

---

## 🖥️ UI Walkthrough

* **Index page** (`GET /`):

    * Auto-lists detected Ollama models with size & family.
    * “Auto-pick light models” selects up to 3 models ≤ \~2.6 GB.
    * Fields:

        * **Topic** – what the round-table will discuss.
        * **Rounds** – how many turns each agent gets (e.g. 2–3).
        * **Models** – the agents (one per selected model).

* **Live page** (`GET /live?...`):

    * Shows members (Agent → Model) and a **live chat**.
    * Streams from `/api/stream` via **EventSource**.
    * One bubble per agent per turn, with **colored avatar** and **model tag**.

---

## 🔁 How “Rounds” Work

* A **round** = each selected agent speaks **once** (round-robin).
* The orchestrator builds each agent’s prompt from:

    1. A **seed** instruction (topic + roles),
    2. The **transcript so far** (agent-labeled),
    3. A short header: “Reply to **previous speaker**” when applicable.
* This encourages short, on-topic replies and critiques.

---

## 🧩 Endpoints

### `GET /`

Renders the index (model picker) and posts to `/live`.

### `GET /live`

Query params:

* `topic` *(required)*
* `rounds` *(default: 2)*
* `models` *(repeatable)* e.g. `&models=llama3.2:1b&models=qwen2.5:1.5b-instruct`

Shows the live UI and opens SSE to `/api/stream`.

### `GET /api/stream` (SSE)

Produces: `text/event-stream`.

Events:

* **start** → `{ phase:"start", agentName, model, round, replyTo? }`
* **delta** → `{ phase:"delta", agentName, delta }` (partial text)
* **done**  → `{ phase:"done", agentName }` (finalizes the bubble)

> The UI concatenates `delta` chunks per agent per turn, then marks the bubble as done.

---

## ⚙️ Configuration

Environment variables:

* `OLLAMA_BASE_URL` (default `http://127.0.0.1:11434`)

Spring (example `application.yml`):

```yaml
ollama:
  base-url: ${OLLAMA_BASE_URL:http://127.0.0.1:11434}
server:
  port: 8080
spring:
  mvc:
    view:
      prefix: /WEB-INF/
      suffix: .jsp
```

---

## 🧠 Prompting & Roles

The orchestrator seeds the conversation in English (recommended for tiny models):

* **Moderator (e.g., Llama1B):** keeps the discussion on the topic and summarizes briefly.
* **Technical Critic (e.g., Qwen1.5B):** challenges assumptions, adds practical constraints.
* **Solution Engineer (e.g., Phi3Mini):** proposes simple, low-cost steps.
* **Risk Auditor (e.g., Phi4Mini):** surfaces trade-offs and risks.

> Tip: Use **concrete, scoped topics** to reduce rambling.
> Example topic:
>
> “Design a tiny CPU-only RAG assistant for an internal handbook. Constraints: ≤8GB RAM, no GPUs, 100–300 pages, ≤1.5s latency. Discuss chunking, embedding size, top-k, prompt template, guardrails, and a minimal eval plan. End with a 10-step checklist.”

---

## 🧪 Test the Ollama API

```bash
curl -s http://127.0.0.1:11434/api/tags | jq
# should list your local models

# quick generate test
curl -s http://127.0.0.1:11434/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "Say hello in one short sentence.",
  "stream": false
}' | jq -r .response
```

---

## 🗂️ Project Structure (abridged)

```
src/main/java/ai/multiagent/ollama_multiagent/
  Application.java
  config/
    AppConfig.java                # reads OLLAMA_BASE_URL etc.
  core/
    Agent.java
    TurnMessage.java
    TurnDelta.java
    ConversationOrchestrator.java # round-robin & SSE streaming
  ollama/
    OllamaClient.java             # /api/tags + /api/generate (stream)
    dto/
      OllamaGenerateRequest.java
      OllamaGenerateChunk.java
  web/
    ConversationController.java   # "/", "/live", "/api/stream"

src/main/webapp/WEB-INF/
  index.jsp                       # model picker + topic/rounds
  live.jsp                        # chat-like streaming UI
```

---

## 🛠️ Development Notes

* **Quality knobs** (optional): set Ollama options (temperature, top\_p, repeat\_penalty, etc.) in `OllamaGenerateRequest`.
  Example:

  ```java
  request.options = Map.of("temperature", 0.4, "top_p", 0.9);
  ```
* **Timeouts**: controller applies a per-run timeout (e.g., `180s`). Tune for slow CPUs.
* **EL vs JS template literals**: avoid `${...}` inside backticks in JSP (EL conflict). Use string concatenation or disable EL on that page:

  ```jsp
  <%@ page isELIgnored="true" %>
  ```
* **macOS DNS warning (Netty)**: if you see
  `netty-resolver-dns-native-macos` warning, you can ignore it or add the native resolver dependency.

---

## 🐛 Troubleshooting

* **`Error: listen tcp 127.0.0.1:11434: address already in use`**

    * Another `ollama serve` is running. Kill it or use a different port and set `OLLAMA_BASE_URL` accordingly.

* **`Could not find or load main class OLLAMA_BASE_URL=http://...`**

    * You passed the env var as a “main class”. Use proper env syntax:

        * macOS/Linux:

          ```bash
          OLLAMA_BASE_URL=http://127.0.0.1:11434 ./mvnw spring-boot:run
          ```
        * Windows (PowerShell):

          ```powershell
          $env:OLLAMA_BASE_URL="http://127.0.0.1:11434"; ./mvnw spring-boot:run
          ```

* **JSP compile error about `StringEscapeUtils`**

    * If you use it, add `org.apache.commons:commons-text`. This project now uses Jackson to safely JSON-encode server values for JS.

* **Garbage or repetitive output from tiny models**

    * Keep prompts short & concrete, lower temperature, and reduce rounds to 1–2.

---

## 🗺️ Roadmap / Ideas

* Per-agent knobs (temperature/top\_p) in the UI
* Markdown rendering for replies
* Save & replay transcripts
* Attach a small RAG tool (local files)
* WebSocket fallback (auto-reconnect)

---

## 🤝 Contributing

PRs and issues are welcome! Please keep changes **small and focused**.
If you’re adding a feature, include a brief demo and notes on resource impact.

---

## 📄 License

MIT (feel free to change if your org prefers another license).

---

## 🙏 Acknowledgements

* [Ollama](https://ollama.com) for the simple local LLM runtime & HTTP API.
* Open-source communities behind LLaMA, Qwen, and Phi model families.