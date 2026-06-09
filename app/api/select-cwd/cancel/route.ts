import { NextResponse } from "next/server";
import { cancelActiveSelectCwdProcess } from "@/lib/select-cwd-process";

// POST /api/select-cwd/cancel
// Closes the native folder picker if it is still waiting for user input.
export async function POST() {
  cancelActiveSelectCwdProcess();
  return NextResponse.json({ ok: true });
}
