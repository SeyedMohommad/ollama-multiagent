package ai.multiagent.ollama_multiagent.core;


public record TurnDelta(
        String agentName,
        String delta,
        boolean done,
        int round,
        String replyTo,
        String phase   // "start" | "delta" | "done"
) {}


