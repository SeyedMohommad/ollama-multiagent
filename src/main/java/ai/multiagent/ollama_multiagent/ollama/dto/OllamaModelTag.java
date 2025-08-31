package ai.multiagent.ollama_multiagent.ollama.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public class OllamaModelTag {
    public String name;      // e.g. "llama3.2:1b"
    public String model;     // same as name in most builds
    public String modified_at;
    public long   size;      // bytes
    public String digest;
    public OllamaModelDetails details;
}