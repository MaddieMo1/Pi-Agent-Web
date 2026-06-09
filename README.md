# Pi Agent Web

Pi Agent Web 是一个用于本地 Pi Coding Agent 的 Web 界面。它可以在浏览器中查看历史会话、继续对话、管理模型配置、浏览工作目录文件，并通过 SSE 实时显示 Agent 的流式输出和工具调用。

仓库地址：[MaddieMo1/Pi-Agent-Web](https://github.com/MaddieMo1/Pi-Agent-Web)

## 快速开始

### 直接运行 npm 包

```bash
npx @maddie1/pi-agent-web@latest
```

启动后打开：

```text
http://localhost:30141
```

如果你的 npm 默认源是国内镜像，刚发布的新版本可能还没同步，可以临时指定官方源：

```bash
npx @maddie1/pi-agent-web@latest --registry https://registry.npmjs.org
```

### 全局安装

```bash
npm install -g @maddie1/pi-agent-web
```

安装后两个命令都可以启动：

```bash
pi-web
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

## 运行当前仓库代码

```bash
git clone https://github.com/MaddieMo1/Pi-Agent-Web.git
cd Pi-Agent-Web
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

开发时不要运行 `next build`，它会生成 `.next/` 构建产物，可能影响本地开发服务。发布 npm 包前才需要构建。

## Windows 一键启动

在 Windows 上可以双击项目根目录的任意一个启动脚本：

```text
启动 Pi Agent.bat
启动 Pi Agent 国内模式.bat
```

普通模式适合网络可以正常访问 npm、GitHub 等服务的电脑。国内模式会自动使用 npm、PyPI、uv 等国内镜像，并优先使用项目内的便携依赖。

首次启动时脚本会自动检查并准备依赖，然后启动开发服务，并在服务可访问后打开浏览器。当前一键启动会处理：

- Node.js / npm：如果系统没有安装且没有 `winget`，会下载便携 Node.js 到项目内缓存目录。
- Git Bash：如果系统没有安装且没有 `winget`，会优先使用 `vendor/PortableGit-*-64-bit.7z.exe` 安装到项目内缓存目录。
- uv / uvx：用于运行 Python 相关工具，例如 PDF 读取、edge-tts 和 Tavily CLI。
- 内置技能：启动时会把 `.agents/skills/` 下的技能同步到当前用户的 `~/.pi/agent/skills/`。

随压缩包分发给其他人时，请保留这些文件和目录：

```text
.agents/skills/
config/
scripts/
vendor/
启动 Pi Agent.bat
启动 Pi Agent 国内模式.bat
package.json
package-lock.json
```

也可以直接运行项目内的打包脚本，它会按白名单生成源码压缩包，并排除 `.git`、`.next`、`node_modules`、本地密钥等不应分发的内容：

```powershell
npm run package:source
```

如果需要让 Tavily 搜索开箱可用，可以复制 `config/tavily-api-key.example.txt` 为 `config/tavily-api-key.txt`，并在第一行填写 Tavily API key。不要把真实 key 提交到公开仓库。

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
- 分支会话合并：将独立会话副本的新增内容摘要写入当前会话上下文
- 会话删除整理：删除父会话时，直接子会话会自动挂到上一级，避免侧边栏树断裂
- 模型配置：查看和编辑本地模型配置
- 工具预设：控制新会话可用的工具集合
- 会话压缩：支持手动或自动 compaction 状态展示
- 文件浏览：在侧边栏浏览当前工作目录文件并在标签页中打开
- 源码打包：通过 `npm run package:source` 生成适合转发给他人的压缩包

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
  session-actions.ts  会话删除和子会话重挂逻辑
  session-merge.ts    分支会话合并摘要生成和追加
  session-reader.ts   解析本地 .jsonl 会话文件
  normalize.ts        标准化 toolCall 字段
  types.ts            共享类型

scripts/
  bootstrap-deps.ps1
  create-desktop-shortcut.ps1
  launch.bat
  package-source.ps1
  self-check.mjs
  wait-and-open.ps1

vendor/
  README.txt
  PortableGit-*-64-bit.7z.exe
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

- 常用自检命令：`npm test`、`node node_modules/typescript/bin/tsc --noEmit`、`node node_modules/eslint/bin/eslint.js .`
- 历史会话浏览走 `lib/session-reader.ts`
- 继续对话、fork、compact 等操作走 `lib/rpc-manager.ts`
- Next.js dev 热更新会重载模块，长期 session registry 存在 `globalThis`
- Fork 后需要销毁旧 wrapper，避免旧 session id 指向 fork 后的新状态
- 删除会话走 `lib/session-actions.ts`，会把直接子会话重挂到被删会话的上级
- 源码压缩包走 `scripts/package-source.ps1` 的白名单，分发前优先使用 `npm run package:source`
- toolCall 字段需要经过 `lib/normalize.ts` 统一格式
- 新旧 compaction 事件都要兼容：`compaction_start/end` 和 `auto_compaction_start/end`
- `.agents/skills/` 是随项目分发的内置技能；其他 `.agents/` 内容、`node_modules/`、`.next/`、`.env*` 等本地目录和敏感文件不会提交到仓库

## 发布状态

npm 包已发布：

```text
@maddie1/pi-agent-web@0.6.11
```

## 分支会话合并

左侧缩进显示的是独立会话副本。可以在已打开目标会话时，将另一个独立会话副本摘要合并到当前会话：

1. 先打开要作为目标的当前会话。
2. 在左侧会话列表中 hover 另一个非当前会话。
3. 点击“合并到当前会话”按钮。
4. 系统会把来源会话中当前会话没有的内容整理为一条“分支会话合并”消息，并写入当前会话上下文。

当前实现是摘要合并，不会重写 `.jsonl` 的 entry tree，也不会修改来源会话。这样更安全，后续继续对话时模型可以读取合并摘要。

相关实现：

```text
app/api/sessions/[id]/merge/route.ts  POST { sourceSessionId }
lib/session-merge.ts                  生成并追加分支会话合并摘要
components/SessionSidebar.tsx         左侧会话合并入口
components/MessageView.tsx            渲染合并摘要 custom message
```

## License

本项目基于 MIT License 开源，详见 [LICENSE](./LICENSE)。
