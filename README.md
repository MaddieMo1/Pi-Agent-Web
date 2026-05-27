# Pi Agent Web

Pi Agent Web 是一个用于本地 Pi Coding Agent 的 Web 界面。它可以在浏览器中查看历史会话、继续对话、管理模型配置、浏览工作目录文件，并通过 SSE 实时显示 Agent 的流式输出和工具调用。

仓库地址：[MaddieMo1/Pi-Agent-Web](https://github.com/MaddieMo1/Pi-Agent-Web)

## 快速开始

### 运行当前仓库代码

```bash
git clone https://github.com/MaddieMo1/Pi-Agent-Web.git
cd Pi-Agent-Web
npm install
npm run dev
```

启动后打开：

```text
http://localhost:30141
```

### 发布到 npm 后运行

当 `@maddiemo1/pi-agent-web` 已发布到 npm 后，可以直接运行：

```bash
npx @maddiemo1/pi-agent-web@latest
```

也可以全局安装后运行：

```bash
npm install -g @maddiemo1/pi-agent-web
pi-web
# 或
pi-agent-web
```

可选参数：

```bash
pi-web --port 8080
pi-web --hostname 127.0.0.1
pi-web -p 8080 -H 127.0.0.1
```

也可以通过环境变量指定端口：

```bash
PORT=8080 pi-web
```

## 本地开发

```bash
npm install
npm run dev
```

开发服务默认运行在：

```text
http://localhost:30141
```

常用检查命令：

```bash
node_modules/.bin/tsc --noEmit
npm run lint
```

开发时不要运行 `next build`，它会生成 `.next/` 构建产物，可能影响本地开发服务。

## Windows 一键启动

在 Windows 上可以双击项目根目录的：

```text
启动 Pi Agent.bat
```

首次启动时脚本会自动安装依赖，然后启动开发服务，并在服务可访问后打开浏览器。

如需创建桌面快捷方式，可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/create-desktop-shortcut.ps1
```

## 主要功能

- 会话浏览：按工作目录分组显示本地 Pi Agent 会话
- 实时对话：通过 SSE 显示 Agent 流式响应
- 工具调用显示：展示 tool call 和 tool result
- 会话 Fork：从某条用户消息创建新的独立会话
- 会话内分支：在同一个 `.jsonl` 会话文件内切换不同分支
- 分支导航：可视化切换同一会话内的多个后续路径
- 模型配置：查看和编辑本地模型配置
- 工具预设：控制新会话可用的工具集合
- 会话压缩：支持手动或自动 compaction 状态展示
- 文件浏览：在侧边栏浏览当前工作目录文件并在标签页中打开

## 数据位置

Pi Agent Web 默认读取本地 Pi Agent 会话目录：

```text
~/.pi/agent/sessions
```

可以通过环境变量指定其他 Agent 数据目录：

```bash
PI_CODING_AGENT_DIR=/path/to/agent-dir npm run dev
```

会话文件格式大致为：

```text
~/.pi/agent/sessions/<encoded-cwd>/<timestamp>_<uuid>.jsonl
```

## 项目结构

```text
app/
  api/
    agent/          Agent 会话创建、命令发送、SSE 事件流
    sessions/       历史会话列表、详情、删除、上下文读取
    files/          本地文件读取
    models/         模型列表和默认模型
    models-config/  模型配置读写

components/
  AppShell.tsx        主布局、URL 状态、标签页管理
  ChatWindow.tsx      消息加载、发送、流式事件处理
  ChatInput.tsx       输入框、模型、工具、压缩控制
  SessionSidebar.tsx  会话树和文件浏览器
  MessageView.tsx     单条消息渲染
  BranchNavigator.tsx 会话内分支导航

lib/
  rpc-manager.ts      AgentSession 生命周期和 registry
  session-reader.ts   解析本地 .jsonl 会话文件
  normalize.ts        标准化 toolCall 字段
  types.ts            共享类型

scripts/
  bootstrap-deps.ps1
  create-desktop-shortcut.ps1
  wait-and-open.ps1
```

## 工作原理

历史会话浏览是只读流程，服务端直接解析 `.jsonl` 文件，不会创建 AgentSession。

继续发送消息时，`lib/rpc-manager.ts` 会通过 `startRpcSession()` 创建或复用内存中的 AgentSession，然后前端通过 `/api/agent/[id]/events` 接收 SSE 事件。

简化流程：

```text
Browser
  -> Next.js API Routes
  -> AgentSessionWrapper
  -> AgentSession
  -> ~/.pi/agent/sessions/*.jsonl
```

## 开发注意事项

- 历史会话浏览走 `lib/session-reader.ts`
- 继续对话、fork、compact 等操作走 `lib/rpc-manager.ts`
- Next.js dev 热更新会重载模块，长期 session registry 存在 `globalThis`
- Fork 后需要销毁旧 wrapper，避免旧 session id 指向 fork 后的新状态
- toolCall 字段需要经过 `lib/normalize.ts` 统一格式
- 新旧 compaction 事件都要兼容：`compaction_start/end` 和 `auto_compaction_start/end`
- `.agents/`、`node_modules/`、`.next/`、`.env*` 等本地目录和敏感文件不会提交到仓库

## License

如果需要开源发布，请在仓库中补充明确的 LICENSE 文件。
