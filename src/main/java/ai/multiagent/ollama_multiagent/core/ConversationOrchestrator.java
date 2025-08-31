package ai.multiagent.ollama_multiagent.core;

import ai.multiagent.ollama_multiagent.ollama.OllamaClient;
import ai.multiagent.ollama_multiagent.ollama.dto.OllamaGenerateChunk;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.util.ArrayList;
import java.util.List;

@Service
public class ConversationOrchestrator {

    private final OllamaClient ollama;

    public ConversationOrchestrator(OllamaClient ollama) {
        this.ollama = ollama;
    }

    public Flux<TurnMessage> runRoundRobin(List<Agent> agents, String topic, int rounds) {
        final List<TurnMessage> transcript = new ArrayList<>();

        String seed = """
    Topic: %s
    [LANG=EN] Answer in English only.
    Please list the current problems/challenges and propose actionable solutions.
    Keep responses short, precise, and step-by-step.
    """.formatted(topic);

        transcript.add(new TurnMessage("user", seed));

        return Flux.range(0, rounds)
                .concatMap(r -> Flux.fromIterable(agents))
                .concatMap(agent -> {
                    StringBuilder prompt = new StringBuilder();
                    if (agent.systemPrompt() != null && !agent.systemPrompt().isBlank()) {
                        prompt.append("### Your role: ").append(agent.systemPrompt()).append("\n\n");
                    }
                    prompt.append("### Conversation so far:\n");
                    for (TurnMessage m : transcript) {
                        prompt.append(m.agentName()).append(": ").append(m.text()).append("\n");
                    }
                    prompt.append("\n### Response of ").append(agent.name()).append(":");

                    StringBuilder acc = new StringBuilder();
                    return ollama.generateStream(agent.model(), prompt.toString())
                            .map((OllamaGenerateChunk ch) -> {
                                if (ch.response != null) acc.append(ch.response);
                                return new TurnMessage(agent.name(), acc.toString());
                            })
                            .takeLast(1)
                            .doOnNext(finalMsg -> transcript.add(finalMsg));
                });
    }



    public Flux<TurnDelta> runRoundTableStream(List<Agent> agents, String topic, int rounds) {
        final List<TurnMessage> transcript = new ArrayList<>();
        transcript.add(new TurnMessage("user", "Topic: " + topic));

        final int WINDOW = 8;

        return Flux.range(1, rounds).concatMap(round ->
                Flux.range(0, agents.size()).concatMap(idx -> {
                    Agent agent = agents.get(idx);

                    String replyTo = (idx == 0) ? "" : agents.get(idx - 1).name();

                    StringBuilder ctx = new StringBuilder();
                    int from = Math.max(0, transcript.size() - WINDOW);
                    for (int i = from; i < transcript.size(); i++) {
                        TurnMessage m = transcript.get(i);
                        ctx.append(m.agentName()).append(": ").append(m.text()).append("\n");
                    }

                    String system = """
          SYSTEM (read carefully):
          - Language: English only.
          - The topic is SAFE. Do NOT refuse unless the content explicitly asks for illegal activity, violence, self-harm, or sharing someone’s private personal data.
          - Do NOT restate rules or context. Do NOT output headings or templates. Output ONLY plain sentences and finish with [END].
          - Length: 3–6 sentences. Be specific and helpful.
          - If the topic is vague (e.g., "hello"), briefly greet AND ask ONE clear clarifying question.
          - If replying to someone, address their last point directly; do not recap everything.
          ---

          Context (do not copy; do not quote literally):
          %s
          """.formatted(ctx.toString());

                    String task = replyTo.isEmpty()
                            ? "You are %s. Open the roundtable on the topic. MESSAGE:".formatted(agent.name())
                            : "You are %s. Reply to %s’s last point directly. Start with a short stance (e.g., “Agree because …” or “Disagree; …”), then add 1–2 supporting sentences and 1 next step. MESSAGE:"
                            .formatted(agent.name(), replyTo);

                    String prompt = system + "\n" + task;

                    StringBuilder acc = new StringBuilder();

                    Flux<TurnDelta> startEvt = Flux.just(new TurnDelta(agent.name(), "", false, round, replyTo, "start"));

                    Flux<TurnDelta> stream = ollama.generateStream(agent.model(), prompt)
                            .map(ch -> {
                                String tok = ch.response != null ? ch.response : "";
                                if (!tok.isEmpty()) acc.append(tok);
                                return new TurnDelta(agent.name(), tok, false, round, replyTo, "delta");
                            })
                            .doOnComplete(() -> {
                                String full = acc.toString();
                                int cut = full.indexOf("[END]");
                                String finalMsg = (cut >= 0) ? full.substring(0, cut).trim() : full.trim();
                                transcript.add(new TurnMessage(agent.name(), finalMsg));
                            })
                            .concatWithValues(new TurnDelta(agent.name(), "", true, round, replyTo, "done"));

                    return startEvt.concatWith(stream);
                })
        );
    }

}
