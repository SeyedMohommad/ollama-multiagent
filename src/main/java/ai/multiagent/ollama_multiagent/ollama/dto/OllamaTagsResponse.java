package ai.multiagent.ollama_multiagent.ollama.dto;


import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public class OllamaTagsResponse {
    public List<OllamaModelTag> models;
}
