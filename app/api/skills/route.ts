import { NextResponse } from "next/server";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { DefaultResourceLoader, getAgentDir, parseFrontmatter } from "@earendil-works/pi-coding-agent";

export const dynamic = "force-dynamic";

function getBundledSkills(existingNames: Set<string>) {
  const skillsDir = join(process.cwd(), ".agents", "skills");
  if (!existsSync(skillsDir)) return [];

  return readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const baseDir = join(skillsDir, entry.name);
      const filePath = join(baseDir, "SKILL.md");
      if (!existsSync(filePath) || existingNames.has(entry.name)) return null;

      const content = readFileSync(filePath, "utf8");
      const { frontmatter } = parseFrontmatter<Record<string, unknown>>(content);
      const name = typeof frontmatter.name === "string" ? frontmatter.name : entry.name;
      if (existingNames.has(name)) return null;
      existingNames.add(name);

      return {
        name,
        description: typeof frontmatter.description === "string" ? frontmatter.description : "",
        filePath,
        baseDir,
        sourceInfo: {
          source: "bundled",
          scope: "project",
          path: filePath,
          baseDir: join(process.cwd(), ".agents"),
        },
        disableModelInvocation: Boolean(frontmatter["disable-model-invocation"]),
      };
    })
    .filter((skill): skill is NonNullable<typeof skill> => skill !== null);
}

// GET /api/skills?cwd=<path>
// Uses DefaultResourceLoader (same logic as AgentSession startup) so settings.json
// skill paths, package skills, and .agents/skills directories are all included.
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const cwd = searchParams.get("cwd");
  if (!cwd) return NextResponse.json({ error: "缺少 cwd" }, { status: 400 });

  try {
    const loader = new DefaultResourceLoader({ cwd, agentDir: getAgentDir() });
    await loader.reload();
    const { skills, diagnostics } = loader.getSkills();
    const names = new Set(skills.map((skill) => skill.name));
    return NextResponse.json({ skills: [...skills, ...getBundledSkills(names)], diagnostics });
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 });
  }
}

// PATCH /api/skills — toggle disable-model-invocation on a SKILL.md file
export async function PATCH(req: Request) {
  try {
    const body = await req.json() as { filePath: string; disableModelInvocation: boolean };
    const { filePath, disableModelInvocation } = body;
    if (!filePath) return NextResponse.json({ error: "缺少 filePath" }, { status: 400 });
    if (!existsSync(filePath)) return NextResponse.json({ error: "未找到文件" }, { status: 404 });

    const content = readFileSync(filePath, "utf8");
    const key = "disable-model-invocation";

    // Use parseFrontmatter to check current value, then do a surgical line edit
    // to preserve the original YAML formatting of all other fields.
    const { frontmatter } = parseFrontmatter<Record<string, unknown>>(content);
    const alreadySet = Boolean(frontmatter[key]);

    let updated = content;
    if (disableModelInvocation && !alreadySet) {
      // Add key after the opening --- line
      updated = content.replace(/^---\r?\n/, `---\n${key}: true\n`);
      // If no frontmatter exists, create one
      if (updated === content) updated = `---\n${key}: true\n---\n${content}`;
    } else if (!disableModelInvocation && alreadySet) {
      // Remove the key line entirely
      updated = content.replace(new RegExp(`^${key}\\s*:.*\\r?\\n`, "m"), "");
    }

    writeFileSync(filePath, updated, "utf8");
    return NextResponse.json({ success: true });
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 });
  }
}
