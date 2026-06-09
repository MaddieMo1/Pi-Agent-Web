import { execFile } from "child_process";
import { existsSync, statSync } from "fs";
import { platform } from "os";
import { resolve } from "path";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { cancelActiveSelectCwdProcess, clearActiveSelectCwdProcess, setActiveSelectCwdProcess } from "@/lib/select-cwd-process";

// POST /api/select-cwd
// Opens a Windows folder picker and returns the selected local path.
export async function POST(req: NextRequest) {
  if (platform() !== "win32") {
    return NextResponse.json({ error: "Folder picker is only available on Windows" }, { status: 501 });
  }

  let initialPath = process.cwd();
  try {
    const body = await req.json() as { cwd?: string };
    if (body.cwd && existsSync(body.cwd) && statSync(body.cwd).isDirectory()) {
      initialPath = resolve(body.cwd);
    }
  } catch {
    // ignore
  }
  const initialPathForPowerShell = initialPath.replace(/'/g, "''");

  const script = `
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
$owner = New-Object System.Windows.Forms.Form
$owner.Text = 'Pi Agent'
$owner.TopMost = $true
$owner.StartPosition = 'CenterScreen'
$owner.Width = 1
$owner.Height = 1
$owner.Opacity = 0
$owner.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$owner.ShowInTaskbar = $false
$owner.Show()
$owner.Activate()
$owner.BringToFront()
[System.Windows.Forms.Application]::DoEvents()
try {
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = '选择 Pi Agent 项目文件夹'
  $dialog.SelectedPath = '${initialPathForPowerShell}'
  $dialog.ShowNewFolderButton = $true
  if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output $dialog.SelectedPath
  }
} finally {
  $owner.Close()
  $owner.Dispose()
}
`;

  try {
    cancelActiveSelectCwdProcess();
    const stdout = await new Promise<string>((resolve, reject) => {
      const child = execFile(
        "powershell.exe",
        ["-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-Command", script],
        { timeout: 120000, windowsHide: false },
        (error, stdout) => {
          clearActiveSelectCwdProcess(child);
          if (error) reject(error);
          else resolve(stdout);
        },
      );
      setActiveSelectCwdProcess(child);
    });
    const cwd = stdout.trim();

    if (!cwd) {
      return NextResponse.json({ cwd: null });
    }
    if (!existsSync(cwd) || !statSync(cwd).isDirectory()) {
      return NextResponse.json({ error: `目录不存在：${cwd}` }, { status: 400 });
    }

    globalThis.__piAllowedRootsCache?.roots.add(cwd);
    return NextResponse.json({ cwd });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 500 });
  }
}
