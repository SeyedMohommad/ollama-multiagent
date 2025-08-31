package ai.multiagent.ollama_multiagent.ollama.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

public class OllamaGenerateRequest {
    public String model;
    public String prompt;
    public Boolean stream;

    @JsonProperty("keep_alive")
    public String keepAlive;

    //  (num_ctx, num_gpu, temperature, ...)
    public Map<String, Object> options;

    public OllamaGenerateRequest(String model, String prompt, Boolean stream,
                                 String keepAlive, Map<String, Object> options) {
        this.model = model;
        this.prompt = prompt;
        this.stream = stream;
        this.keepAlive = keepAlive;
        this.options = options;
    }
}
