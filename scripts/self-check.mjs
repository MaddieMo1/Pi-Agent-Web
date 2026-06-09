import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { deleteSessionFileWithReparent } from "../lib/session-actions.ts";
import { createSessionMergeSummary, MERGE_CUSTOM_TYPE } from "../lib/session-merge.ts";
import { normalizeToolCalls } from "../lib/normalize.ts";

const requiredPackagePaths = [
  ".agents/skills",
  "app",
  "bin",
  "components",
  "config",
  "hooks",
  "lib",
  "public",
  "scripts",
  "vendor",
  "eslint.config.mjs",
  "LICENSE",
  "next.config.ts",
  "package.json",
  "package-lock.json",
  "postcss.config.mjs",
  "README.md",
  "tailwind.config.ts",
  "tsconfig.json",
  "启动 Pi Agent.bat",
  "启动 Pi Agent 国内模式.bat",
];

const explicitPackageScriptPaths = requiredPackagePaths.filter((path) => !path.endsWith(".bat"));

const excludedPackagePaths = [
  ".git",
  ".next",
  ".pi-bootstrap",
  "node_modules",
  "config/tavily-api-key.txt",
  "next-env.d.ts",
  "tsconfig.tsbuildinfo",
];

test("normalizes legacy toolCall blocks from session files", () => {
  const msg = {
    role: "assistant",
    model: "m",
    provider: "p",
    content: [
      { type: "text", text: "before" },
      { type: "toolCall", id: "call-1", name: "read", arguments: { path: "a.ts" } },
    ],
  };

  const normalized = normalizeToolCalls(msg);
  assert.equal(normalized.role, "assistant");
  assert.deepEqual(normalized.content[1], {
    type: "toolCall",
    toolCallId: "call-1",
    toolName: "read",
    input: { path: "a.ts" },
  });
});

test("keeps already-normalized toolCall blocks intact", () => {
  const msg = {
    role: "assistant",
    model: "m",
    provider: "p",
    content: [
      { type: "toolCall", toolCallId: "call-2", toolName: "bash", input: { command: "pwd" } },
    ],
  };

  const normalized = normalizeToolCalls(msg);
  assert.deepEqual(normalized.content[0], msg.content[0]);
});

test("does not rewrite non-assistant messages", () => {
  const msg = { role: "user", content: "hello" };
  assert.equal(normalizeToolCalls(msg), msg);
});

test("source package allowlist exists and excludes local state", () => {
  for (const path of requiredPackagePaths) {
    assert.ok(existsSync(path), `missing package path: ${path}`);
  }

  const packageScript = readFileSync("scripts/package-source.ps1", "utf8");
  for (const path of explicitPackageScriptPaths) {
    assert.ok(packageScript.includes(`"${path}"`), `package script omits ${path}`);
  }
  assert.ok(packageScript.includes('"*.bat"'), "package script should include root launcher scripts");
  for (const path of excludedPackagePaths) {
    assert.ok(packageScript.includes(`"${path}"`), `package script should explicitly exclude ${path}`);
  }
});

test("key UI labels remain readable UTF-8 text", () => {
  const branchNavigator = readFileSync("components/BranchNavigator.tsx", "utf8");
  const messageView = readFileSync("components/MessageView.tsx", "utf8");

  assert.ok(branchNavigator.includes("会话内分支"));
  assert.ok(messageView.includes("独立会话"));
  assert.ok(!branchNavigator.includes("\uFFFD"));
  assert.ok(!messageView.includes("\uFFFD"));
});

test("deleting a session reparents only direct child session files", () => {
  const dir = mkdtempSync(join(tmpdir(), "pi-agent-web-session-actions-"));
  try {
    const grandparent = join(dir, "grandparent.jsonl");
    const parent = join(dir, "parent.jsonl");
    const child = join(dir, "child.jsonl");
    const grandchild = join(dir, "grandchild.jsonl");
    const unrelated = join(dir, "unrelated.jsonl");
    const malformed = join(dir, "malformed.jsonl");

    writeFileSync(grandparent, JSON.stringify({ type: "session", id: "grandparent", cwd: dir }) + "\n");
    writeFileSync(parent, JSON.stringify({ type: "session", id: "parent", cwd: dir, parentSession: grandparent }) + "\n");
    writeFileSync(child, JSON.stringify({ type: "session", id: "child", cwd: dir, parentSession: parent }) + "\n");
    writeFileSync(grandchild, JSON.stringify({ type: "session", id: "grandchild", cwd: dir, parentSession: child }) + "\n");
    writeFileSync(unrelated, JSON.stringify({ type: "session", id: "unrelated", cwd: dir }) + "\n");
    writeFileSync(malformed, "not json\n");

    const result = deleteSessionFileWithReparent(parent);
    assert.deepEqual(result, { reparentedCount: 1 });
    assert.equal(existsSync(parent), false);

    const childHeader = JSON.parse(readFileSync(child, "utf8").split("\n")[0]);
    const grandchildHeader = JSON.parse(readFileSync(grandchild, "utf8").split("\n")[0]);
    const unrelatedHeader = JSON.parse(readFileSync(unrelated, "utf8").split("\n")[0]);

    assert.equal(childHeader.parentSession, grandparent);
    assert.equal(grandchildHeader.parentSession, child);
    assert.equal(unrelatedHeader.parentSession, undefined);
    assert.equal(readFileSync(malformed, "utf8"), "not json\n");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("creates merge summaries from source-only session entries", () => {
  const shared = {
    type: "message",
    id: "shared-user",
    parentId: null,
    timestamp: "2026-01-01T00:00:00.000Z",
    message: { role: "user", content: "shared prompt" },
  };
  const sourceOnly = {
    type: "message",
    id: "source-only",
    parentId: "shared-user",
    timestamp: "2026-01-01T00:01:00.000Z",
    message: { role: "assistant", content: [{ type: "text", text: "source branch answer" }], model: "m", provider: "p" },
  };

  const summary = createSessionMergeSummary([shared, sourceOnly], [shared], "source session");
  assert.ok(summary);
  assert.equal(summary.sourceUniqueEntryCount, 1);
  assert.equal(summary.summarizedItemCount, 1);
  assert.match(summary.content, /分支会话合并摘要/);
  assert.match(summary.content, /source branch answer/);
  assert.equal(createSessionMergeSummary([shared], [shared], "source session"), null);
});

test("merge summaries include custom merge message entries from source branches", () => {
  const sourceOnlyCustom = {
    type: "custom_message",
    id: "merge-source",
    parentId: null,
    timestamp: "2026-01-01T00:01:00.000Z",
    customType: MERGE_CUSTOM_TYPE,
    content: "nested merge note",
    display: true,
  };

  const summary = createSessionMergeSummary([sourceOnlyCustom], [], "source session");
  assert.ok(summary);
  assert.match(summary.content, /nested merge note/);
});
