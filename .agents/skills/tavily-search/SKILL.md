---
name: tavily-search
description: |
  Search the web with LLM-optimized results via the Tavily CLI. Use this skill when the user wants to search the web, find articles, look up information, get recent news, discover sources, or says "search for", "find me", "look up", "what's the latest on", "find articles about", or needs current information from the internet. Returns relevant results with content snippets, relevance scores, and metadata optimized for LLM consumption. Supports domain filtering, time ranges, and multiple search depths.
allowed-tools: Bash(tvly *)
---

# tavily search

Web search returning LLM-optimized results with content snippets and relevance scores.

## Before running any command

If `tvly` is not found on PATH, use the bundled startup dependency setup or install it with:

```bash
uv tool install tavily-cli
```

If search asks for authentication, run:

```bash
tvly login
```

## When to use

- The user asks to search the web, look up current information, find sources, or get latest news.
- The user asks Chinese web-search requests such as: 搜索, 联网搜索, 查一下, 找资料, 最新消息, 近期新闻, 帮我查.
- The task needs current information beyond local files or model knowledge.

## Quick start

```bash
tvly search "your query" --json
```

## Advanced examples

```bash
tvly search "quantum computing" --depth advanced --max-results 10 --json
tvly search "AI news" --time-range week --topic news --json
tvly search "SEC filings" --include-domains sec.gov,reuters.com --json
tvly search "react hooks tutorial" --include-raw-content --max-results 3 --json
```

## Options

| Option | Description |
|--------|-------------|
| `--depth` | `ultra-fast`, `fast`, `basic` (default), `advanced` |
| `--max-results` | Max results, 0-20 (default: 5) |
| `--topic` | `general` (default), `news`, `finance` |
| `--time-range` | `day`, `week`, `month`, `year` |
| `--start-date` | Results after date (YYYY-MM-DD) |
| `--end-date` | Results before date (YYYY-MM-DD) |
| `--include-domains` | Comma-separated domains to include |
| `--exclude-domains` | Comma-separated domains to exclude |
| `--country` | Boost results from country |
| `--include-answer` | Include AI answer (`basic` or `advanced`) |
| `--include-raw-content` | Include full page content (`markdown` or `text`) |
| `--include-images` | Include image results |
| `--include-image-descriptions` | Include AI image descriptions |
| `--chunks-per-source` | Chunks per source (advanced/fast depth only) |
| `-o, --output` | Save output to file |
| `--json` | Structured JSON output |

## Tips

- Keep queries under 400 characters.
- Break complex questions into smaller search queries.
- Use `--include-raw-content` when full page text is needed.
- Use `--include-domains` to focus on trusted sources.
- Use `--time-range` for recent information.
- Read from stdin: `echo "query" | tvly search - --json`
