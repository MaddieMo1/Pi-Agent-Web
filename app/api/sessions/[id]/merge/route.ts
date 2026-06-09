import { NextResponse } from "next/server";
import { resolveSessionPath } from "@/lib/session-reader";
import { getRpcSession } from "@/lib/rpc-manager";
import {
  appendMergeSummaryToSessionFile,
  createSessionMergeSummaryFromFiles,
  MERGE_CUSTOM_TYPE,
} from "@/lib/session-merge";

export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id: targetSessionId } = await params;

  try {
    const { sourceSessionId } = await req.json() as { sourceSessionId?: string };
    if (!sourceSessionId) {
      return NextResponse.json({ error: "缺少来源会话" }, { status: 400 });
    }
    if (sourceSessionId === targetSessionId) {
      return NextResponse.json({ error: "不能合并当前会话自身" }, { status: 400 });
    }

    const [targetFilePath, sourceFilePath] = await Promise.all([
      resolveSessionPath(targetSessionId),
      resolveSessionPath(sourceSessionId),
    ]);
    if (!targetFilePath) {
      return NextResponse.json({ error: "未找到目标会话" }, { status: 404 });
    }
    if (!sourceFilePath) {
      return NextResponse.json({ error: "未找到来源会话" }, { status: 404 });
    }

    const summary = createSessionMergeSummaryFromFiles(sourceFilePath, targetFilePath);
    if (!summary) {
      return NextResponse.json({ error: "来源会话没有可合并的新内容" }, { status: 409 });
    }

    const liveTarget = getRpcSession(targetSessionId);
    let entryId: string;
    if (liveTarget?.isAlive()) {
      const result = await liveTarget.send({
        type: "append_custom_message",
        customType: MERGE_CUSTOM_TYPE,
        content: summary.content,
        display: true,
        details: {
          sourceSessionId,
          sourceUniqueEntryCount: summary.sourceUniqueEntryCount,
          summarizedItemCount: summary.summarizedItemCount,
        },
      }) as { entryId?: string };
      entryId = result.entryId ?? "";
    } else {
      entryId = appendMergeSummaryToSessionFile(targetFilePath, summary);
    }

    return NextResponse.json({
      ok: true,
      entryId,
      sourceUniqueEntryCount: summary.sourceUniqueEntryCount,
      summarizedItemCount: summary.summarizedItemCount,
    });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 500 });
  }
}
