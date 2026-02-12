# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Rosin ("Pure Output") is a multi-LLM verification tool that combats AI hallucinations by running queries through multiple language models in sequence — each stage verifies and refines the previous output. It exists as two apps sharing the same verification logic:

- **Web app** (React/Express) — in `client/` and `server/`
- **Native iOS app** (SwiftUI) — in `ios/`

## Build & Run Commands

### Web App
```bash
npm run dev          # Start dev server (Express + Vite HMR)
npm run build        # Production build
npm run start        # Run production build
npm run check        # TypeScript type checking
npm run db:push      # Push Drizzle schema to PostgreSQL
```

### iOS App
```bash
# Build for simulator
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Install & launch on booted simulator
xcrun simctl install booted ios/Rosin.app
xcrun simctl launch booted com.rosin.app
```

No test suite exists for either platform.

## Architecture

### Verification Pipeline (core concept, shared across both apps)

A query passes through 2-3 LLM stages sequentially. Each stage gets a different system prompt based on its position:
- **Stage 1**: Generate initial thorough response
- **Middle stages**: Verify, correct errors, cross-check facts from previous output
- **Final stage**: Synthesize all previous stages into a verified answer

The pipeline emits events: `stage_start` → `content` (streaming chunks) → `stage_complete` → `summary` → `done`. On error, `stage_error` stops the pipeline.

### Web App

`server/routes.ts` is the core — it handles `POST /api/verify` using SSE streaming. Each provider (OpenAI, Anthropic, Gemini, xAI) has its own streaming function. The client in `client/src/pages/terminal.tsx` consumes the SSE stream and updates React state.

Path aliases: `@/*` → `client/src/*`, `@shared/*` → `shared/*`

### iOS App (34 Swift files, zero dependencies)

The iOS app calls LLM APIs directly from the device — no backend server.

**Data flow:** `TerminalView` → `TerminalViewModel` → `VerificationPipelineManager` → `LLMStreamingService` implementations

Key architectural decisions:
- **3 providers only**: Anthropic, Gemini, xAI (OpenAI dropped)
- **`URLSession.bytes(for:)`** for streaming — no delegates, pure async/await
- **`@MainActor`** on ViewModel and PipelineManager — `@Published` mutations are safe; network I/O suspends via `await`
- **SSELineParser** is shared across all providers — consumes `AsyncBytes`, yields `data:` payloads
- **Keychain** with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for API key storage
- **No database** — stateless verification tool matching web app behavior

Three distinct streaming formats:
- `AnthropicStreamingService`: Anthropic's native SSE (`content_block_delta` events)
- `GeminiStreamingService`: Google's SSE (`candidates[0].content.parts[0].text`), system prompt concatenated into user message
- `XAIStreamingService`: OpenAI-compatible format (`choices[0].delta.content`)

### Shared Data Models

Web: `shared/schema.ts` — Zod schemas + Drizzle ORM types
iOS: `ios/Rosin/Models/` — Swift structs mirroring the same shapes

Both define: LLMProvider, LLMModel, StageOutput (with status enum), VerificationSummary, stage prompts.

## Design System

Terminal/CLI aesthetic throughout. Monospace fonts only (web: JetBrains Mono; iOS: SF Mono via `.system(design: .monospaced)`). ASCII dividers (`─` thin, `═` thick). Status indicators: `[RUN]` with pulse, `[OK]`, `[ERR]`, `[...]`.

iOS colors defined in `Assets.xcassets` with light/dark variants: RosinGreen (`#16A34A`/`#22C35E`), RosinDestructive (`#C51111`/`#E02525`), RosinBackground (`#FFFFFF`/`#0F0F0F`).

## Environment Variables (Web)

See `.env.example`. Required: `AI_INTEGRATIONS_OPENAI_API_KEY`, `AI_INTEGRATIONS_ANTHROPIC_API_KEY`, `AI_INTEGRATIONS_GEMINI_API_KEY`, `XAI_API_KEY`, `DATABASE_URL`.

## Available LLM Models

| Provider | Models |
|----------|--------|
| Anthropic | claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5 |
| Gemini | gemini-2.5-flash, gemini-2.5-pro |
| xAI/Grok | grok-3, grok-3-fast |
| OpenAI (web only) | gpt-4o, gpt-4o-mini, gpt-4-turbo |
