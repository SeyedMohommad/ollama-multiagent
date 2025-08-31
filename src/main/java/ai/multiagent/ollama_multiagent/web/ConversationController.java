package ai.multiagent.ollama_multiagent.web;

import ai.multiagent.ollama_multiagent.core.Agent;
import ai.multiagent.ollama_multiagent.core.ConversationOrchestrator;
import ai.multiagent.ollama_multiagent.core.TurnMessage;
import ai.multiagent.ollama_multiagent.core.TurnDelta;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

@Controller
public class ConversationController {

    private final ConversationOrchestrator orchestrator;

    public ConversationController(ConversationOrchestrator orchestrator) {
        this.orchestrator = orchestrator;
    }

    @GetMapping("/")
    public String index() {
        return "index";
    }

    @PostMapping("/run")
    public String run(
            @RequestParam String topic,
            @RequestParam(defaultValue = "2") int rounds,
            @RequestParam(required = false, defaultValue = "false") boolean useLlama1B,
            @RequestParam(required = false, defaultValue = "false") boolean useQwen15B,
            @RequestParam(required = false, defaultValue = "false") boolean usePhi3Mini,
            @RequestParam(required = false, defaultValue = "false") boolean usePhi4Mini,
            Model model
    ) {
        List<Agent> agents = new ArrayList<>();

        if (useLlama1B) {
            agents.add(new Agent("Llama1B", "llama3.2:1b",
                    "Moderator: keep the discussion on-topic and summarize cleanly."));
        }
        if (useQwen15B) {
            agents.add(new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct",
                    "Technical Critic: check risks & assumptions; provide concrete examples."));
        }
        if (usePhi3Mini) {
            agents.add(new Agent("Phi3Mini", "phi3:mini",
                    "Solution Engineer: suggest simple, low-cost solutions."));
        }
        if (usePhi4Mini) {
            agents.add(new Agent("Phi4Mini", "phi4-mini:latest",
                    "Risk Auditor: highlight risks, costs, and trade-offs."));
        }

        // Lightweight defaults if nothing selected:
        if (agents.isEmpty()) {
            agents = List.of(
                    new Agent("Llama1B", "llama3.2:1b",
                            "Moderator: keep the discussion on-topic and summarize cleanly."),
                    new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct",
                            "Technical Critic: check risks & assumptions; provide concrete examples.")
            );
        }

        List<TurnMessage> transcript = orchestrator
                .runRoundRobin(agents, topic, rounds)
                .timeout(Duration.ofSeconds(180))
                .collectList()
                .block();

        model.addAttribute("topic", topic);
        model.addAttribute("rounds", rounds);
        model.addAttribute("messages", transcript);
        model.addAttribute("agents", agents);
        return "result";
    }

    @GetMapping("/live")
    public String livePage(
            @RequestParam String topic,
            @RequestParam(defaultValue = "2") int rounds,
            @RequestParam(defaultValue = "true") boolean useLlama1B,
            @RequestParam(defaultValue = "true") boolean useQwen15B,
            @RequestParam(defaultValue = "false") boolean usePhi3Mini,
            @RequestParam(defaultValue = "false") boolean usePhi4Mini,
            Model model
    ) {
        List<Agent> agents = new ArrayList<>();
        if (useLlama1B)  agents.add(new Agent("Llama1B", "llama3.2:1b", "Moderator: concise summaries"));
        if (useQwen15B)  agents.add(new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct", "Technical critic"));
        if (usePhi3Mini) agents.add(new Agent("Phi3Mini", "phi3:mini", "Solution engineer"));
        if (usePhi4Mini) agents.add(new Agent("Phi4Mini", "phi4-mini:latest", "Risk auditor"));
        if (agents.isEmpty()) { // lightweight default
            agents = List.of(
                    new Agent("Llama1B", "llama3.2:1b", "Moderator"),
                    new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct", "Technical critic")
            );
        }

        model.addAttribute("topic", topic);
        model.addAttribute("rounds", rounds);
        model.addAttribute("agents", agents);
        // pass flags for SSE query:
        model.addAttribute("useLlama1B", useLlama1B);
        model.addAttribute("useQwen15B", useQwen15B);
        model.addAttribute("usePhi3Mini", usePhi3Mini);
        model.addAttribute("usePhi4Mini", usePhi4Mini);
        return "live";
    }

    @GetMapping(value = "/api/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @ResponseBody
    public Flux<ServerSentEvent<TurnDelta>> stream(
            @RequestParam String topic,
            @RequestParam(defaultValue = "2") int rounds,
            @RequestParam(defaultValue = "true") boolean useLlama1B,
            @RequestParam(defaultValue = "true") boolean useQwen15B,
            @RequestParam(defaultValue = "false") boolean usePhi3Mini,
            @RequestParam(defaultValue = "false") boolean usePhi4Mini
    ) {
        List<Agent> agents = new ArrayList<>();
        if (useLlama1B)  agents.add(new Agent("Llama1B", "llama3.2:1b", "Moderator: concise summaries"));
        if (useQwen15B)  agents.add(new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct", "Technical critic"));
        if (usePhi3Mini) agents.add(new Agent("Phi3Mini", "phi3:mini", "Solution engineer"));
        if (usePhi4Mini) agents.add(new Agent("Phi4Mini", "phi4-mini:latest", "Risk auditor"));
        if (agents.isEmpty()) {
            agents = List.of(
                    new Agent("Llama1B", "llama3.2:1b", "Moderator"),
                    new Agent("Qwen1.5B", "qwen2.5:1.5b-instruct", "Technical critic")
            );
        }

        return orchestrator.runRoundTableStream(agents, topic, rounds)
                .map(d -> ServerSentEvent.<TurnDelta>builder(d)
                        .event(d.phase())   // "start" | "delta" | "done"
                        .build());
    }
}
