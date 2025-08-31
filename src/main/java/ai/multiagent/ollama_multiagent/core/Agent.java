package ai.multiagent.ollama_multiagent.core;

public record Agent(
        String name,
        String model,
        String systemPrompt
) {}

