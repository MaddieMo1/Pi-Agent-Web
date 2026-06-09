import { readdirSync, readFileSync, unlinkSync, writeFileSync } from "fs";
import { dirname, join, resolve } from "path";

type SessionHeaderWithParent = {
  type?: string;
  parentSession?: string;
};

function normalizeForCompare(filePath: string): string {
  return resolve(filePath).replace(/\\/g, "/").toLowerCase();
}

export function readParentSessionPath(filePath: string): string | undefined {
  try {
    const firstLine = readFileSync(filePath, "utf8").split("\n")[0];
    const header = JSON.parse(firstLine) as SessionHeaderWithParent;
    return header.type === "session" ? header.parentSession : undefined;
  } catch {
    return undefined;
  }
}

export function reparentDirectChildSessions(filePath: string, parentSessionPath: string | undefined): number {
  const dir = dirname(filePath);
  const targetPath = normalizeForCompare(filePath);
  let changed = 0;

  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".jsonl")) continue;

    const childPath = join(dir, file);
    if (normalizeForCompare(childPath) === targetPath) continue;

    try {
      const content = readFileSync(childPath, "utf8");
      const lines = content.split("\n");
      const header = JSON.parse(lines[0]) as SessionHeaderWithParent;
      if (header.type !== "session" || !header.parentSession) continue;
      if (normalizeForCompare(header.parentSession) !== targetPath) continue;

      header.parentSession = parentSessionPath;
      lines[0] = JSON.stringify(header);
      writeFileSync(childPath, lines.join("\n"));
      changed += 1;
    } catch {
      // Malformed or unreadable session files are ignored by the sidebar as orphaned.
    }
  }

  return changed;
}

export function deleteSessionFileWithReparent(filePath: string): { reparentedCount: number } {
  const parentSessionPath = readParentSessionPath(filePath);
  const reparentedCount = reparentDirectChildSessions(filePath, parentSessionPath);
  unlinkSync(filePath);
  return { reparentedCount };
}
