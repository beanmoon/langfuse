import { describe, expect, it } from "vitest";

import { toCompactVerbosity } from "./toCompactVerbosity";

describe("toCompactVerbosity", () => {
  it("extracts text from OTel GenAI parts for compact input and output previews", () => {
    const input = [
      {
        role: "user",
        parts: [{ type: "text", content: "Hi there" }],
      },
    ];
    const output = [
      {
        role: "assistant",
        parts: [{ type: "text", content: "Hello! How can I help?" }],
      },
    ];

    expect(toCompactVerbosity(input)).toEqual({
      success: true,
      data: '"Hi there"',
    });
    expect(toCompactVerbosity(output)).toEqual({
      success: true,
      data: '"Hello! How can I help?"',
    });
  });

  it.each([
    [
      "a stringified message array",
      JSON.stringify([
        {
          role: "assistant",
          parts: [{ type: "text", content: "Stringified output" }],
        },
      ]),
      '"Stringified output"',
    ],
    [
      "a single message",
      {
        role: "assistant",
        parts: [{ type: "text", content: "Single output" }],
      },
      '"Single output"',
    ],
    [
      "a messages wrapper",
      {
        messages: [
          {
            role: "assistant",
            parts: [{ type: "text", content: "Wrapped output" }],
          },
        ],
      },
      '"Wrapped output"',
    ],
  ])("extracts text from %s", (_label, value, expected) => {
    expect(toCompactVerbosity(value)).toEqual({
      success: true,
      data: expected,
    });
  });
});
