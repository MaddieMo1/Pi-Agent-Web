"use client";

import { useEffect, useMemo, useState } from "react";
import type { ChangeEvent, CSSProperties, FormEvent, ReactNode } from "react";

type AuthUser = {
  id: string;
  username: string;
  nickname?: string;
  avatarUrl?: string;
};

type AuthStatus = "checking" | "signed-out" | "signed-in";

const TOKEN_KEY = "maddie-agent-auth-token";
const USER_KEY = "maddie-agent-auth-user";
const INSTALL_ID_KEY = "maddie-agent-install-id";
const SESSION_POS_KEY = "maddie-agent-session-window-pos-v2";
const MAX_AVATAR_SOURCE_SIZE = 5 * 1024 * 1024;
const MAX_AVATAR_DATA_SIZE = 1_500_000;
const AUTH_SERVER_URL = (process.env.NEXT_PUBLIC_AUTH_SERVER_URL || "http://127.0.0.1:4000").replace(/\/+$/, "");

async function sha256Hex(value: string) {
  if (!crypto.subtle) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193);
    }
    return `fnv1a-${(hash >>> 0).toString(16).padStart(8, "0")}`;
  }
  const encoded = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function getOrCreateInstallId() {
  const existing = localStorage.getItem(INSTALL_ID_KEY);
  if (existing) return existing;
  const next = typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  localStorage.setItem(INSTALL_ID_KEY, next);
  return next;
}

async function getDeviceHash() {
  const installId = getOrCreateInstallId();
  const fingerprint = [
    installId,
    location.origin,
    navigator.userAgent,
    navigator.language,
    Intl.DateTimeFormat().resolvedOptions().timeZone,
  ].join("|");
  return sha256Hex(fingerprint);
}

async function authRequest(path: string, body: Record<string, unknown>, token?: string) {
  const res = await fetch(`${AUTH_SERVER_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(typeof data.error === "string" ? data.error : "认证服务暂时不可用");
  }
  return data;
}

function parseStoredUser(rawUser: string | null) {
  if (!rawUser) return null;
  try {
    return JSON.parse(rawUser) as AuthUser;
  } catch {
    localStorage.removeItem(USER_KEY);
    return null;
  }
}

function readFileAsDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("读取图片失败"));
    reader.readAsDataURL(file);
  });
}

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("图片无法加载"));
    image.src = src;
  });
}

async function fileToAvatarDataUrl(file: File) {
  if (!file.type.startsWith("image/")) throw new Error("请选择图片文件");
  if (file.size > MAX_AVATAR_SOURCE_SIZE) throw new Error("图片不能超过 5MB");

  const rawDataUrl = await readFileAsDataUrl(file);
  const image = await loadImage(rawDataUrl);
  const size = 256;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("当前浏览器无法处理图片");

  const scale = Math.max(size / image.width, size / image.height);
  const width = image.width * scale;
  const height = image.height * scale;
  const x = (size - width) / 2;
  const y = (size - height) / 2;
  ctx.clearRect(0, 0, size, size);
  ctx.drawImage(image, x, y, width, height);

  const dataUrl = canvas.toDataURL("image/jpeg", 0.86);
  if (dataUrl.length > MAX_AVATAR_DATA_SIZE) throw new Error("头像图片太大，请换一张更小的图片");
  return dataUrl;
}

export function AuthGate({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>("checking");
  const [user, setUser] = useState<AuthUser | null>(null);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileUsername, setProfileUsername] = useState("");
  const [profileNickname, setProfileNickname] = useState("");
  const [profileAvatarUrl, setProfileAvatarUrl] = useState("");
  const [profileMessage, setProfileMessage] = useState("");
  const [profileSaving, setProfileSaving] = useState(false);
  const [avatarPicking, setAvatarPicking] = useState(false);
  const [sessionPos, setSessionPos] = useState<{ x: number; y: number } | null>(null);

  const authHost = useMemo(() => {
    try {
      return new URL(AUTH_SERVER_URL).host;
    } catch {
      return AUTH_SERVER_URL;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function verifyStoredToken() {
      const token = localStorage.getItem(TOKEN_KEY);
      const rawUser = localStorage.getItem(USER_KEY);
      if (!token) {
        setStatus("signed-out");
        return;
      }
      try {
        const deviceHash = await getDeviceHash();
        const data = await authRequest("/api/verify", { deviceHash }, token) as { user?: AuthUser };
        if (cancelled) return;
        const nextUser = data.user ?? parseStoredUser(rawUser);
        setUser(nextUser);
        if (nextUser) syncProfileForm(nextUser);
        setStatus("signed-in");
      } catch {
        if (cancelled) return;
        localStorage.removeItem(TOKEN_KEY);
        localStorage.removeItem(USER_KEY);
        setStatus("signed-out");
      }
    }
    verifyStoredToken();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(SESSION_POS_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw) as { x?: number; y?: number };
      if (typeof parsed.x === "number" && typeof parsed.y === "number") {
        setSessionPos({
          x: Math.max(8, Math.min(window.innerWidth - 220, parsed.x)),
          y: Math.max(4, Math.min(window.innerHeight - 48, parsed.y)),
        });
      }
    } catch {
      localStorage.removeItem(SESSION_POS_KEY);
    }
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    setSubmitting(true);
    try {
      const deviceHash = await getDeviceHash();
      const data = await authRequest("/api/login", { username, password, deviceHash }) as { token: string; user: AuthUser };
      localStorage.setItem(TOKEN_KEY, data.token);
      localStorage.setItem(USER_KEY, JSON.stringify(data.user));
      setUser(data.user);
      syncProfileForm(data.user);
      setPassword("");
      setStatus("signed-in");
    } catch (error) {
      const text = error instanceof Error ? error.message : "登录失败";
      setMessage(text === "Failed to fetch" ? "无法连接认证服务，请确认 auth-server 已启动并已重启到最新版本。" : text);
    } finally {
      setSubmitting(false);
    }
  }

  function handleLogout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    setUser(null);
    setProfileOpen(false);
    setProfileMessage("");
    setUsername("");
    setPassword("");
    setStatus("signed-out");
  }

  function syncProfileForm(nextUser: AuthUser) {
    setProfileUsername(nextUser.username);
    setProfileNickname(nextUser.nickname ?? "");
    setProfileAvatarUrl(nextUser.avatarUrl ?? "");
  }

  function openProfile() {
    if (user) syncProfileForm(user);
    setProfileMessage("");
    setProfileOpen(true);
  }

  async function handleProfileSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setProfileMessage("");
    setProfileSaving(true);
    try {
      const token = localStorage.getItem(TOKEN_KEY);
      if (!token) throw new Error("登录已过期，请重新登录");
      const deviceHash = await getDeviceHash();
      const data = await authRequest("/api/profile", {
        username: profileUsername,
        nickname: profileNickname,
        avatarUrl: profileAvatarUrl,
        deviceHash,
      }, token) as { user: AuthUser };
      localStorage.setItem(USER_KEY, JSON.stringify(data.user));
      setUser(data.user);
      syncProfileForm(data.user);
      setProfileMessage("资料已保存");
      setProfileOpen(false);
    } catch (error) {
      const text = error instanceof Error ? error.message : "保存失败";
      setProfileMessage(text === "Failed to fetch" ? "无法连接认证服务，请确认 auth-server 已启动。" : text);
    } finally {
      setProfileSaving(false);
    }
  }

  async function handleAvatarFileChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setProfileMessage("");
    setAvatarPicking(true);
    try {
      setProfileAvatarUrl(await fileToAvatarDataUrl(file));
    } catch (error) {
      setProfileMessage(error instanceof Error ? error.message : "头像处理失败");
    } finally {
      setAvatarPicking(false);
    }
  }

  function handleSessionPointerDown(event: React.PointerEvent<HTMLDivElement>) {
    if ((event.target as HTMLElement).closest("button")) return;
    const el = event.currentTarget;
    const rect = el.getBoundingClientRect();
    const offsetX = event.clientX - rect.left;
    const offsetY = event.clientY - rect.top;
    el.setPointerCapture(event.pointerId);

    const handleMove = (moveEvent: PointerEvent) => {
      const x = Math.max(8, Math.min(window.innerWidth - rect.width - 8, moveEvent.clientX - offsetX));
      const y = Math.max(4, Math.min(window.innerHeight - rect.height - 8, moveEvent.clientY - offsetY));
      setSessionPos({ x, y });
    };
    const handleUp = () => {
      window.removeEventListener("pointermove", handleMove);
      window.removeEventListener("pointerup", handleUp);
      const nextRect = el.getBoundingClientRect();
      localStorage.setItem(SESSION_POS_KEY, JSON.stringify({ x: nextRect.left, y: nextRect.top }));
    };

    window.addEventListener("pointermove", handleMove);
    window.addEventListener("pointerup", handleUp, { once: true });
  }

  if (status === "checking") {
    return (
      <main className="auth-screen">
        <div className="auth-loading">正在校验登录状态...</div>
      </main>
    );
  }

  if (status === "signed-in") {
    const displayName = user?.nickname || user?.username || "当前账号";
    const avatarLetter = displayName.slice(0, 1).toUpperCase();
    const sessionAvatarStyle: CSSProperties | undefined = user?.avatarUrl ? { backgroundImage: `url(${user.avatarUrl})` } : undefined;
    const previewAvatarUrl = profileAvatarUrl.trim();
    const previewName = profileNickname || profileUsername || "M";
    const profileAvatarStyle: CSSProperties | undefined = previewAvatarUrl ? { backgroundImage: `url(${previewAvatarUrl})` } : undefined;
    return (
      <>
        {children}
        <div
          className={sessionPos ? "auth-session auth-session-custom-pos" : "auth-session"}
          style={sessionPos ? { left: sessionPos.x, top: sessionPos.y } : undefined}
          onPointerDown={handleSessionPointerDown}
          title="拖拽可移动"
        >
          <div className={user?.avatarUrl ? "auth-avatar has-image" : "auth-avatar"} style={sessionAvatarStyle} aria-hidden="true">
            {user?.avatarUrl ? "" : avatarLetter}
          </div>
          <div className="auth-session-info">
            <span className="auth-session-label">已登录</span>
            <span className="auth-session-user">{displayName}</span>
          </div>
          <button type="button" onClick={openProfile}>资料</button>
          <button type="button" onClick={handleLogout}>退出</button>
        </div>
        {profileOpen && (
          <div className="profile-backdrop" onClick={() => setProfileOpen(false)}>
            <form className="profile-panel" onSubmit={handleProfileSubmit} onClick={(event) => event.stopPropagation()}>
              <div className="profile-head">
                <div className={previewAvatarUrl ? "auth-avatar profile-avatar has-image" : "auth-avatar profile-avatar"} style={profileAvatarStyle} aria-hidden="true">
                  {previewAvatarUrl ? "" : previewName.slice(0, 1).toUpperCase()}
                </div>
                <div>
                  <h2>个人资料</h2>
                  <p>用户名会用于下次登录，昵称和头像用于界面展示。</p>
                </div>
              </div>
              {profileMessage && <div className={profileMessage === "资料已保存" ? "profile-message ok" : "profile-message error"}>{profileMessage}</div>}
              <label className="auth-field">
                用户名
                <input value={profileUsername} onChange={(event) => setProfileUsername(event.target.value)} required />
              </label>
              <label className="auth-field">
                昵称
                <input value={profileNickname} onChange={(event) => setProfileNickname(event.target.value)} placeholder="例如 Maddie" />
              </label>
              <label className="auth-field">
                头像
                <input value={profileAvatarUrl.startsWith("data:") ? "已选择本地图片" : profileAvatarUrl} onChange={(event) => setProfileAvatarUrl(event.target.value)} placeholder="https://example.com/avatar.png" disabled={profileAvatarUrl.startsWith("data:")} />
              </label>
              <div className="avatar-actions">
                <label className="avatar-file-button">
                  {avatarPicking ? "处理中..." : "选择本地图片"}
                  <input type="file" accept="image/png,image/jpeg,image/webp,image/gif" onChange={handleAvatarFileChange} disabled={avatarPicking} />
                </label>
                <button type="button" className="profile-secondary" onClick={() => setProfileAvatarUrl("")}>清除头像</button>
              </div>
              <div className="profile-actions">
                <button type="button" className="profile-secondary" onClick={() => setProfileOpen(false)}>取消</button>
                <button type="submit" className="auth-submit profile-submit" disabled={profileSaving}>
                  {profileSaving ? "正在保存..." : "保存资料"}
                </button>
              </div>
            </form>
          </div>
        )}
      </>
    );
  }

  return (
    <main className="auth-screen">
      <form className="auth-card" onSubmit={handleSubmit}>
        <div className="auth-brand">Maddie</div>
        <div className="auth-copy">
          <h1>Maddie Agent</h1>
          <p>登录后继续使用你的 Agent 工作台</p>
        </div>
        {message && <div className="auth-alert">{message}</div>}
        <label className="auth-field">
          账号
          <input
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            autoComplete="username"
            placeholder="输入管理员创建的账号"
            required
          />
        </label>
        <label className="auth-field">
          密码
          <input
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            type="password"
            autoComplete="current-password"
            placeholder="输入密码"
            required
          />
        </label>
        <button className="auth-submit" type="submit" disabled={submitting}>
          {submitting ? "正在登录..." : "登录"}
        </button>
        <p className="auth-footnote">认证服务：{authHost}</p>
      </form>
    </main>
  );
}
