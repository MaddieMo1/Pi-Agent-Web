import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { AgentMessage, AssistantContentBlock, SessionEntry } from "./types";

const MAX_MERGE_ITEMS = 30;
const MAX_ITEM_CHARS = 700;
const MAX_SUMMARY_CHARS = 16000;
export const MERGE_CUSTOM_TYPE = "session_merge_summary";

export interface MergeSummary {
  content: string;
  sourceUniqueEntryCount: number;
  summarizedItemCount: number;
}

function truncateText(text: string, maxChars: number): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxChars) return normalized;
  return normalized.slice(0, maxChars - 1).trimEnd() + "...";
}

function textFromMessageContent(content: AgentMessage["content"]): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  const texts: string[] = [];
  for (const block of content) {
    if (block.type === "text" && "text" in block) {
      texts.push(String(block.text));
    }
  }
  return texts.join("\n");
}

function toolNamesFromAssistantBlocks(content: AssistantContentBlock[]): string[] {
  return content
    .filter((block) => block.type === "toolCall")
    .map((block) => block.toolName)
    .filter(Boolean);
}

function describeMessage(message: AgentMessage): string | null {
  if (message.role === "toolResult") return null;

  if (message.role === "assistant") {
    const text = textFromMessageContent(message.content);
    if (text.trim()) return `助手：${truncateText(text, MAX_ITEM_CHARS)}`;

    const toolNames = toolNamesFromAssistantBlocks(message.content ?? []);
    if (toolNames.length > 0) {
      return `助手调用工具：${[...new Set(toolNames)].join(", ")}`;
    }
    return null;
  }

  if (message.role === "user") {
    const text = textFromMessageContent(message.content);
    return text.trim() ? `用户：${truncateText(text, MAX_ITEM_CHARS)}` : null;
  }

  if (message.role === "custom") {
    const text = typeof message.content === "string" ? message.content : textFromMessageContent(message.content);
    return text.trim() ? `自定义消息：${truncateText(text, MAX_ITEM_CHARS)}` : null;
  }

  return null;
}

function describeEntry(entry: SessionEntry): string | null {
  if (entry.type === "message") {
    return describeMessage(entry.message);
  }

  if (entry.type === "custom_message") {
    const text = typeof entry.content === "string" ? entry.content : textFromMessageContent(entry.content);
    return text.trim() ? `自定义消息：${truncateText(text, MAX_ITEM_CHARS)}` : null;
  }

  if (entry.type === "compaction") {
    return `压缩摘要：${truncateText(entry.summary, MAX_ITEM_CHARS)}`;
  }

  if (entry.type === "branch_summary") {
    return `分支摘要：${truncateText(entry.summary, MAX_ITEM_CHARS)}`;
  }

  return null;
}

function firstUserText(entries: SessionEntry[]): string | null {
  for (const entry of entries) {
    if (entry.type !== "message" || entry.message.role !== "user") continue;
    const text = textFromMessageContent(entry.message.content);
    if (text.trim()) return truncateText(text, 80);
  }
  return null;
}

export function createSessionMergeSummary(
  sourceEntries: SessionEntry[],
  targetEntries: SessionEntry[],
  sourceLabel: string,
): MergeSummary | null {
  const targetEntryIds = new Set(targetEntries.map((entry) => entry.id));
  const uniqueSourceEntries = sourceEntries.filter((entry) => !targetEntryIds.has(entry.id));
  const items = uniqueSourceEntries
    .map(describeEntry)
    .filter((item): item is string => Boolean(item))
    .slice(0, MAX_MERGE_ITEMS);

  if (items.length === 0) return null;

  const omittedCount = Math.max(0, uniqueSourceEntries.length - items.length);
  const lines = [
    "【分支会话合并摘要】",
    "",
    `来源会话：${sourceLabel}`,
    `合并时间：${new Date().toISOString()}`,
    "",
    "以下内容来自另一个独立会话副本，已合并为当前会话后续上下文：",
    "",
    ...items.map((item, idx) => `${idx + 1}. ${item}`),
  ];

  if (omittedCount > 0) {
    lines.push("", `另有 ${omittedCount} 条来源记录未展开。`);
  }

  return {
    content: truncateText(lines.join("\n"), MAX_SUMMARY_CHARS),
    sourceUniqueEntryCount: uniqueSourceEntries.length,
    summarizedItemCount: items.length,
  };
}

export function createSessionMergeSummaryFromFiles(sourceFilePath: string, targetFilePath: string): MergeSummary | null {
  const sourceManager = SessionManager.open(sourceFilePath);
  const targetManager = SessionManager.open(targetFilePath);
  const sourceEntries = sourceManager.getEntries() as unknown as SessionEntry[];
  const targetEntries = targetManager.getEntries() as unknown as SessionEntry[];
  const sourceLabel = sourceManager.getSessionName() || firstUserText(sourceEntries) || sourceManager.getSessionId();
  return createSessionMergeSummary(sourceEntries, targetEntries, sourceLabel);
}

export function appendMergeSummaryToSessionFile(targetFilePath: string, summary: MergeSummary): string {
  const targetManager = SessionManager.open(targetFilePath);
  return targetManager.appendCustomMessageEntry(
    MERGE_CUSTOM_TYPE,
    summary.content,
    true,
    {
      sourceUniqueEntryCount: summary.sourceUniqueEntryCount,
      summarizedItemCount: summary.summarizedItemCount,
    },
  );
}
