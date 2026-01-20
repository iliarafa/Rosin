# Multi-LLM Verification Terminal

## Overview

A terminal-style web application that verifies LLM outputs by running queries through multiple AI models in sequence. The system implements a multi-stage verification pipeline using OpenAI, Anthropic, and Google Gemini models to detect hallucinations and distill truth from AI responses.

The application presents a CLI/terminal aesthetic interface where users submit queries that pass through 2-4 configurable LLM stages. Each model verifies and refines the previous output, with results streamed in real-time via Server-Sent Events (SSE).

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Framework**: React 18 with TypeScript
- **Routing**: Wouter (lightweight client-side routing)
- **State Management**: TanStack React Query for server state
- **UI Components**: shadcn/ui component library built on Radix UI primitives
- **Styling**: Tailwind CSS with CSS variables for theming
- **Build Tool**: Vite with HMR support
- **Design Pattern**: Terminal/CLI aesthetic with monospace typography (JetBrains Mono, Fira Code)

### Backend Architecture
- **Runtime**: Node.js with Express
- **Language**: TypeScript with ESM modules
- **API Pattern**: RESTful endpoints with SSE for streaming responses
- **Build**: esbuild for production bundling with selective dependency bundling

### Multi-LLM Pipeline
- **Supported Providers**: OpenAI, Anthropic, Google Gemini, xAI/Grok
- **Available Models**:
  - OpenAI: gpt-4o, gpt-4o-mini, gpt-4-turbo
  - Anthropic: claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5
  - Gemini: gemini-2.5-flash, gemini-2.5-pro
  - xAI/Grok: grok-3, grok-3-fast
- **Streaming**: Real-time response streaming via SSE with stage-by-stage output
- **Chain Configuration**: User-configurable 2-4 stage verification chains (selectable via dropdown)

### Data Layer
- **ORM**: Drizzle ORM with PostgreSQL dialect
- **Schema Validation**: Zod with drizzle-zod integration
- **Storage Abstraction**: Interface-based storage pattern (IStorage) with in-memory implementation available

### Project Structure
```
client/           # React frontend application
  src/
    components/   # UI components (model-selector, terminal-input, stage-block)
    pages/        # Route components (terminal.tsx)
    hooks/        # Custom React hooks
    lib/          # Utilities and query client
server/           # Express backend
  routes.ts       # API endpoints including SSE streaming
  storage.ts      # Data access layer
  replit_integrations/  # AI service integrations (audio, chat, image, batch)
shared/           # Shared types and schemas
  schema.ts       # Drizzle schema and Zod validation
```

## External Dependencies

### AI Provider Integrations
- **OpenAI API**: Text completions via `openai` SDK
- **Anthropic API**: Claude models via `@anthropic-ai/sdk`
- **Google Gemini**: Via `@google/genai` SDK with Replit AI Integrations support
- **xAI/Grok API**: Via OpenAI-compatible SDK

### Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `AI_INTEGRATIONS_OPENAI_API_KEY`: OpenAI API key
- `AI_INTEGRATIONS_OPENAI_BASE_URL`: OpenAI API base URL
- `AI_INTEGRATIONS_ANTHROPIC_API_KEY`: Anthropic API key
- `AI_INTEGRATIONS_ANTHROPIC_BASE_URL`: Anthropic API base URL
- `AI_INTEGRATIONS_GEMINI_API_KEY`: Gemini API key
- `AI_INTEGRATIONS_GEMINI_BASE_URL`: Gemini API base URL
- `XAI_API_KEY`: xAI/Grok API key (required for Grok models)

### Database
- PostgreSQL for persistent storage
- Drizzle Kit for schema migrations (`npm run db:push`)

### Key NPM Packages
- `express`: Web server framework
- `drizzle-orm`: Database ORM
- `@tanstack/react-query`: Data fetching and caching
- `wouter`: Client-side routing
- Radix UI primitives: Accessible component foundations
- `tailwindcss`: Utility-first CSS framework