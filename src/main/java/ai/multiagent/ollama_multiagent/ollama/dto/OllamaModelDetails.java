package ai.multiagent.ollama_multiagent.ollama.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public class OllamaModelDetails {
    public String parent_model;
    public String format;              // "gguf"
    public String family;              // "llama" / "phi3" / "qwen2" ...
    public List<String> families;      // optional
    public String parameter_size;      // e.g. "1.2B"
    public String quantization_level;  // e.g. "Q4_K_M"
}
