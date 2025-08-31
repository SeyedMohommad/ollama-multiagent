package ai.multiagent.ollama_multiagent.core;

public record TurnMessage(
        String agentName,
        String text
) {}