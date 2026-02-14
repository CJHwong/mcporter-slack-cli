export interface Scenario {
  id: string;
  name: string;
  prompt: string;
}

/**
 * Benchmark scenarios ordered by increasing complexity.
 * In "isolated" mode each runs as a fresh session; in "single" mode
 * they chain within one session per config.
 */
export function getScenarios(channel: string): Scenario[] {
  return [
    {
      id: "s1-list-read",
      name: "List + Read",
      prompt: `List the public channels in this Slack workspace, then read the last 5 messages from ${channel}. Provide a brief summary of what's being discussed.`,
    },
    {
      id: "s2-list-read-thread",
      name: "List + Read + Thread",
      prompt: `List the public channels in this Slack workspace. Read the last 10 messages from ${channel}. If any message has thread replies (non-empty ThreadTs), read the most recent thread and summarize the thread discussion.`,
    },
    {
      id: "s3-search-thread",
      name: "Search + Thread",
      prompt: `Search for messages mentioning "test" in the Slack workspace. Pick the most relevant result that has thread replies, read that full thread, and summarize the discussion.`,
    },
    {
      id: "s4-full-research",
      name: "Full Research",
      prompt: `List the public channels. Then search for messages mentioning "test" across the workspace. Read the most relevant thread from ${channel} and provide a summary of the key points discussed.`,
    },
    {
      id: "s5-read-write",
      name: "Read + Write",
      prompt: `Read the last 5 messages from ${channel}. Write a one-sentence summary of the conversation and post it as a new message to ${channel} with the prefix "[Benchmark Test]".`,
    },
  ];
}
