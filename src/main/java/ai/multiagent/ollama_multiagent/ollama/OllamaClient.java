package ai.multiagent.ollama_multiagent.ollama;


import ai.multiagent.ollama_multiagent.ollama.dto.OllamaGenerateChunk;
import ai.multiagent.ollama_multiagent.ollama.dto.OllamaGenerateRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;

import java.util.HashMap;
import java.util.Map;

@Component
public class OllamaClient {

    private final WebClient webClient;
    private final ObjectMapper mapper = new ObjectMapper();

    private final String keepAlive;
    private final int numCtx;
    private final int numGpu;
    private final double temperature;

    public OllamaClient(
            WebClient ollamaWebClient,
            @Value("${ollama.keep-alive}") String keepAlive,
            @Value("${ollama.num-ctx}") int numCtx,
            @Value("${ollama.num-gpu}") int numGpu,
            @Value("${ollama.temperature}") double temperature
    ) {
        this.webClient = ollamaWebClient;
        this.keepAlive = keepAlive;
        this.numCtx = numCtx;
        this.numGpu = numGpu;
        this.temperature = temperature;
    }

    public Flux<OllamaGenerateChunk> generateStream(String model, String prompt) {
        Map<String, Object> options = new HashMap<>();
        options.put("num_ctx", numCtx);
        options.put("num_gpu", numGpu);
//        options.put("temperature", temperature);
        options.put("num_predict", 160);
        options.put("temperature", 0.3);
        options.put("top_p", 0.9);
        options.put("repeat_penalty", 1.3);
        options.put("num_thread", Runtime.getRuntime().availableProcessors());
        options.put("stop", java.util.List.of("[END]"));


        OllamaGenerateRequest body =
                new OllamaGenerateRequest(model, prompt, true, keepAlive, options);

        return webClient.post()
                .uri("/api/generate")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToFlux(String.class)
                .flatMap(s -> Flux.fromArray(s.split("\\r?\\n"))) // ← به‌جای flatMapMany
                .map(this::parseChunk)
                .takeUntil(ch -> Boolean.TRUE.equals(ch.done));

    }

    private OllamaGenerateChunk parseChunk(String line) {
        try {
            return mapper.readValue(line, OllamaGenerateChunk.class);
        } catch (Exception e) {
            OllamaGenerateChunk err = new OllamaGenerateChunk();
            err.response = "";
            err.done = false;
            return err;
        }
    }
}
