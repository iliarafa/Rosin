# Rosin AI — Pure Output

A terminal-style web application that combats AI hallucinations by running queries through multiple language models in sequence. Each stage verifies and refines the previous output to distill truth from AI responses.

## Features

- **Multi-Stage Verification**: Run queries through 2-4 LLMs in sequence, each cross-checking the last
- **4 AI Providers**: OpenAI, Anthropic, Google Gemini, and xAI/Grok
- **Live Research**: Real-time web search via Tavily to ground answers with current information
- **Adversarial Mode**: Middle stages aggressively challenge claims and demand evidence
- **Final Verified Answer**: Prominent, visually distinct card with toggle between full answer and concise bullet summary
- **Real-time Streaming**: Watch responses stream in via Server-Sent Events
- **Verification Summary**: Automated consistency analysis, hallucination risk scoring, and contradiction detection
- **Configurable Pipeline**: Choose which models to use at each stage
- **Export & Share**: Download results as CSV/PDF or share via link
- **Verification History**: Browse past verifications and disagreement heatmap
- **Terminal Aesthetic**: Clean CLI-style interface with monospace typography
- **Mobile Optimized**: Fully responsive with iOS safe area support
- **Native iOS App**: SwiftUI companion app calling LLM APIs directly from device

## Available Models

| Provider | Models |
|----------|--------|
| OpenAI | gpt-4o, gpt-4o-mini, gpt-4-turbo |
| Anthropic | claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5 |
| Google Gemini | gemini-2.5-flash, gemini-2.5-pro |
| xAI/Grok | grok-3, grok-3-fast |

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/iliarafa/Rosin.git
cd Rosin
```

### 2. Install dependencies

```bash
npm install
```

### 3. Configure environment variables

Copy the example environment file and add your API keys:

```bash
cp .env.example .env
```

Edit `.env` with your actual API keys:

```
AI_INTEGRATIONS_OPENAI_API_KEY=sk-...
AI_INTEGRATIONS_ANTHROPIC_API_KEY=sk-ant-...
AI_INTEGRATIONS_GEMINI_API_KEY=...
XAI_API_KEY=xai-...
TAVILY_API_KEY=tvly-...          # optional — enables Live Research
DATABASE_URL=postgresql://...
SESSION_SECRET=your-secret-key
```

### 4. Set up the database

```bash
npm run db:push
```

### 5. Start the development server

```bash
npm run dev
```

The app will be available at `http://localhost:5000`

## How It Works

1. Enter your query in the terminal input
2. Select the number of verification stages (2-4)
3. Choose which model to use at each stage
4. Optionally enable **[LIVE]** for web-grounded answers or **[ADV]** for adversarial verification
5. Press RUN or hit Enter
6. Watch as each model processes and verifies the previous output
7. Get a **Final Verified Answer** card with confidence assessment and a concise summary toggle

## Live Research (Web Grounding)

LLMs have a knowledge cutoff — they don't know about events after their training date. The **Live Research** toggle solves this by searching the web in real-time before verification begins.

### How it works
1. Toggle **[LIVE: ON]** in the header bar
2. When you run a query, Rosin first searches the web via [Tavily](https://tavily.com) (up to 5 sources)
3. The search results are injected as context into the first pipeline stage
4. All subsequent verification stages benefit from grounded, current information

### Setup
1. Sign up for a free Tavily API key at [tavily.com](https://tavily.com)
2. Add `TAVILY_API_KEY=tvly-...` to your `.env` file
3. The [LIVE] toggle appears automatically — if no key is set, it falls back gracefully with a warning

The free tier provides 1,000 searches/month, which is plenty for most users.

## Recommended Configurations

### Balanced (Recommended)
| Stage | Model | Purpose |
|-------|-------|---------|
| 1 | gpt-4o | Fast, capable baseline response |
| 2 | claude-sonnet-4-5 | Cross-provider verification |
| 3 | gemini-2.5-pro | Deep analysis and synthesis |
| 4 | grok-3 | Final independent check |

### Speed Optimized
| Stage | Model | Purpose |
|-------|-------|---------|
| 1 | gpt-4o-mini | Fast initial response |
| 2 | gemini-2.5-flash | Quick cross-check |
| 3 | claude-haiku-4-5 | Rapid synthesis |

### Maximum Accuracy
| Stage | Model | Purpose |
|-------|-------|---------|
| 1 | gpt-4-turbo | Thorough initial analysis |
| 2 | claude-opus-4-5 | Deep verification |
| 3 | gemini-2.5-pro | Comprehensive cross-check |
| 4 | gpt-4o | Final synthesis |

### Key Principles
- **Mix providers**: Never use the same provider twice in a row
- **Start fast, go deep**: Use faster models early, thorough models later
- **End with synthesis**: Final stage should excel at summarization

## Tech Stack

- **Frontend**: React, TypeScript, Tailwind CSS, shadcn/ui
- **Backend**: Node.js, Express, TypeScript
- **Database**: PostgreSQL with Drizzle ORM
- **AI SDKs**: OpenAI, Anthropic, Google GenAI
- **Web Search**: Tavily (optional)

## License

MIT
