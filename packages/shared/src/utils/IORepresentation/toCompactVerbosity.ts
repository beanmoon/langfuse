import { toCompactVerbosityChatML } from "./chatML/toCompactVerbosityChatML";

function normalizeOtelGenAiMessage(message: unknown): unknown {
  if (!message || typeof message !== "object" || Array.isArray(message)) {
    return message;
  }

  const record = message as Record<string, unknown>;
  if ("content" in record || !Array.isArray(record.parts)) {
    return message;
  }

  const textParts = record.parts
    .filter(
      (part): part is Record<string, unknown> =>
        Boolean(part) &&
        typeof part === "object" &&
        !Array.isArray(part) &&
        (part as Record<string, unknown>).type === "text" &&
        typeof (part as Record<string, unknown>).content === "string",
    )
    .map((part) => part.content as string);

  return textParts.length > 0
    ? { ...record, content: textParts.join("") }
    : message;
}

function normalizeOtelGenAiMessages(io: unknown): unknown {
  if (Array.isArray(io)) {
    return io.map(normalizeOtelGenAiMessage);
  }

  if (!io || typeof io !== "object") {
    return io;
  }

  const record = io as Record<string, unknown>;
  if (Array.isArray(record.messages)) {
    return {
      ...record,
      messages: record.messages.map(normalizeOtelGenAiMessage),
    };
  }

  return normalizeOtelGenAiMessage(io);
}

/**
 * Returns a compact representation of IO data for display in tables.
 * Strategy: Normalize OTel GenAI messages, then try ChatML extraction.
 *
 * @param io - The input or output data to compact
 * @returns Compact representation or null if no data
 */
export function toCompactVerbosity(io: unknown): {
  success: boolean;
  data: string | null;
} {
  if (io === undefined || io === null) return { success: false, data: null };

  // Parse stringified JSON if needed
  let parsedIO = io;
  if (typeof io === "string") {
    try {
      parsedIO = JSON.parse(io);
    } catch {
      // Continue with original input
    }
  }

  const normalizedIO = normalizeOtelGenAiMessages(parsedIO);

  // Try ChatML compact representation extraction
  const chatMLCompact = toCompactVerbosityChatML(normalizedIO);
  if (chatMLCompact.success) {
    return { success: true, data: chatMLCompact.data };
  }

  return { success: false, data: null };
}
