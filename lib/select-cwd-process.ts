import { execFile, type ChildProcess } from "child_process";

declare global {
  var __piSelectCwdProcess: ChildProcess | undefined;
}

export function setActiveSelectCwdProcess(child: ChildProcess) {
  globalThis.__piSelectCwdProcess = child;
}

export function clearActiveSelectCwdProcess(child: ChildProcess) {
  if (globalThis.__piSelectCwdProcess === child) {
    globalThis.__piSelectCwdProcess = undefined;
  }
}

export function cancelActiveSelectCwdProcess() {
  const child = globalThis.__piSelectCwdProcess;
  if (!child?.pid) return;

  execFile("taskkill.exe", ["/PID", String(child.pid), "/T", "/F"], { windowsHide: true }, () => {});
  globalThis.__piSelectCwdProcess = undefined;
}
