# Multi-LLM Verification Terminal

A terminal-style web application that verifies LLM outputs by running queries through multiple AI models in sequence. The system implements a multi-stage verification pipeline to detect hallucinations and distill truth from AI responses.

## Features

- **Multi-Stage Verification**: Run queries through 2-4 LLMs in sequence
- **4 AI Providers**: OpenAI, Anthropic, Google Gemini, and xAI/Grok
- **Real-time Streaming**: Watch responses stream in via Server-Sent Events
- **Configurable Pipeline**: Choose which models to use at each stage
- **Terminal Aesthetic**: Clean CLI-style interface with monospace typography
- **Mobile Optimized**: Fully responsive with iOS safe area support
- **Bilingual README**: In-app documentation in English and Greek

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
git clone https://github.com/yourusername/multi-llm-verification.git
cd multi-llm-verification
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
4. Press RUN or hit Enter
5. Watch as each model processes and verifies the previous output
6. Get a final synthesized response with confidence assessment

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

## License

MIT
