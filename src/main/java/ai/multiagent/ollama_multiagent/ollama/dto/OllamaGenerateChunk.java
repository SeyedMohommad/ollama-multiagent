package ai.multiagent.ollama_multiagent.ollama.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class OllamaGenerateChunk {
    public String model;
    public String response;
    public Boolean done;
    public String done_reason;
}
