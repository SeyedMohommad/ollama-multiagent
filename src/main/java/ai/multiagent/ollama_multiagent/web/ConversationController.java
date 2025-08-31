package ai.multiagent.ollama_multiagent.web;

import ai.multiagent.ollama_multiagent.core.Agent;
import ai.multiagent.ollama_multiagent.core.ConversationOrchestrator;
import ai.multiagent.ollama_multiagent.core.TurnMessage;
import ai.multiagent.ollama_multiagent.core.TurnDelta;
import ai.multiagent.ollama_multiagent.ollama.OllamaClient;
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
    private final OllamaClient ollamaClient;

    public ConversationController(ConversationOrchestrator orchestrator, OllamaClient ollamaClient) {
        this.orchestrator = orchestrator;
        this.ollamaClient = ollamaClient;
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
            @RequestParam(name = "models", required = false) List<String> models,
            Model model
    ) {
        if (models == null || models.isEmpty()) {
            List<ai.multiagent.ollama_multiagent.ollama.dto.OllamaModelTag> all =
                    ollamaClient.listModels().timeout(Duration.ofSeconds(5)).onErrorReturn(java.util.List.of()).block();
            all.sort(java.util.Comparator.comparingLong(m -> m.size));
            models = new ArrayList<>();
            for (var t : all) {
                if (models.size() >= 2) break;
                models.add(t.name);
            }
        }

        List<Agent> agents = buildAgentsFromModels(models);

        model.addAttribute("topic", topic);
        model.addAttribute("rounds", rounds);
        model.addAttribute("agents", agents);
        model.addAttribute("selectedModels", models); // برای SSE
        return "live";
    }

    @GetMapping(value = "/api/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @ResponseBody
    public Flux<ServerSentEvent<TurnDelta>> stream(
            @RequestParam String topic,
            @RequestParam(defaultValue = "2") int rounds,
            @RequestParam(name = "models", required = false) List<String> models
    ) {
        List<Agent> agents = buildAgentsFromModels(
                (models == null || models.isEmpty())
                        ? java.util.List.of("llama3.2:1b", "qwen2.5:1.5b-instruct")
                        : models);

        return orchestrator.runRoundTableStream(agents, topic, rounds)
                .map(d -> ServerSentEvent.<TurnDelta>builder(d)
                        .event(d.phase()) // "start" | "delta" | "done"
                        .build());
    }


    @GetMapping("/")
    public String index(Model model) {
        java.util.List<ai.multiagent.ollama_multiagent.ollama.dto.OllamaModelTag> modelsList =
                ollamaClient.listModels()
                        .timeout(Duration.ofSeconds(5))
                        .onErrorReturn(java.util.List.of()) // اگر Ollama down بود
                        .block();

        // small to big
        modelsList.sort(java.util.Comparator.comparingLong(m -> m.size));
        model.addAttribute("models", modelsList);
        return "index";
    }

    private String friendlyName(String model) {
        if (model == null) return "Agent";
        // samples:
        if (model.startsWith("llama3.2:1b")) return "Llama1B";
        if (model.startsWith("qwen2.5:1.5b")) return "Qwen1.5B";
        if (model.startsWith("phi3:mini"))    return "Phi3Mini";
        if (model.startsWith("phi4-mini"))    return "Phi4Mini";
        // defaults: TitleCase + suffix
        String base = model.replaceAll("[:/].*$", "");
        String label = base.isEmpty() ? "Agent" : Character.toUpperCase(base.charAt(0)) + base.substring(1);
        String suffix = model.contains(":") ? " (" + model.substring(model.indexOf(':')+1) + ")" : "";
        return label + suffix;
    }

    private List<Agent> buildAgentsFromModels(List<String> models) {
        if (models == null || models.isEmpty()) return java.util.List.of();
        String[] roles = new String[]{
                "Moderator: keep the discussion on-topic and summarize cleanly.",
                "Technical Critic: check risks & assumptions; provide concrete examples.",
                "Solution Engineer: suggest simple, low-cost solutions.",
                "Risk Auditor: highlight risks, costs, and trade-offs."
        };
        List<Agent> agents = new ArrayList<>();
        for (int i = 0; i < models.size(); i++) {
            String m = models.get(i);
            String name = friendlyName(m);
            String role = roles[i % roles.length];
            agents.add(new Agent(name, m, role));
        }
        return agents;
    }


}
