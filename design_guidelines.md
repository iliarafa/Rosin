# Design Guidelines: Multi-LLM Verification Terminal

## Design Approach

**Reference-Based:** Terminal/CLI interface aesthetic inspired by modern developer tools like VSCode's integrated terminal, Warp, and iTerm2. The design prioritizes content legibility, clear information hierarchy, and minimal visual distraction.

**Core Principle:** Authenticity to terminal aesthetics while maintaining modern usability standards. Every element serves a functional purpose.

---

## Typography

**Font Families:**
- Primary: `'JetBrains Mono', 'Fira Code', 'Courier New', monospace`
- All text uses monospace for consistent terminal feel

**Type Scale:**
- Input/Output text: `text-sm` (14px)
- Stage headers: `text-base` (16px) 
- System messages: `text-xs` (12px)
- Prompt indicator: `text-sm` (14px)

**Font Weights:**
- Regular: 400 (default for all content)
- Medium: 500 (stage numbers, model names)
- Bold: 600 (error states only)

---

## Layout System

**Spacing Primitives:** Tailwind units of 2, 4, 6, and 8
- Micro spacing: `p-2`, `gap-2`
- Standard spacing: `p-4`, `gap-4`, `mb-4`
- Section spacing: `p-6`, `mb-6`
- Large spacing: `p-8`, `mb-8`

**Container Structure:**
- Full viewport height layout (`h-screen`)
- Single column, full-width content
- No sidebars, no chrome - pure terminal view
- Fixed header (model selection) + scrollable output area
- Input field anchored at bottom

**Grid/Column Usage:** None - terminal is linear/sequential by nature

---

## Component Library

### A. Model Selection Bar (Top Fixed)
- Horizontal layout with 4 model dropdowns
- Label format: `[1]`, `[2]`, `[3]`, `[4]` in brackets
- Dropdowns showing provider + model name
- Minimal borders, subtle hover states
- Position: `sticky top-0` with backdrop blur

### B. Terminal Output Area
- Scrollable main content area
- Each verification stage displays as:
  ```
  > STAGE [N]: [Model Name]
  ────────────────────────────────
  [LLM response content streaming here...]
  ────────────────────────────────
  ```
- Clear visual separators using ASCII-style horizontal rules
- Auto-scroll to latest content during streaming

### C. Input Field (Bottom Fixed)
- Full-width text input with prompt indicator: `$ _`
- Submit button styled as terminal command (or Enter to submit)
- Position: `sticky bottom-0` with backdrop blur
- Textarea expands vertically as user types

### D. Status Indicators
- Processing states shown with terminal-style animations:
  - `⣾ Processing Stage 1...` (rotating spinner characters)
  - `✓ Stage 1 complete`
  - `✗ Error in Stage 2`
- Inline with stage headers

### E. Response Display
- Each LLM response in sequential blocks
- Preserve markdown formatting but render in monospace
- Code blocks have subtle background distinction
- Streaming cursor effect: `▊` blinking at end of active stream

### F. Summary Section
- After Stage 4, display final output section:
  ```
  ════════════════════════════════
  VERIFIED OUTPUT
  ════════════════════════════════
  [Final distilled response]
  
  VERIFICATION SUMMARY:
  • Consistency score
  • Hallucinations detected
  • Confidence level
  ════════════════════════════════
  ```

---

## Visual Treatment

**Background Hierarchy:**
- Main background: Dark terminal shade
- Input/header areas: Slightly lighter with blur effect
- Active streaming section: Subtle highlight
- Completed sections: Return to base shade

**Border Style:**
- Minimal 1px borders where necessary
- ASCII-style separators (`─`, `═`) for visual breaks
- No rounded corners - sharp, terminal aesthetic

**Text Treatment:**
- High contrast for legibility
- Subtle opacity variations for hierarchy (100%, 80%, 60%)
- Selection color: Terminal highlight style

**Interactive States:**
- Hover: Subtle brightness increase (no color shifts)
- Focus: Simple outline, no fancy effects
- Active/Pressed: Slight darkening
- Disabled: 40% opacity

---

## Behavior & Interaction

**Streaming Animation:**
- Character-by-character reveal (fast, ~10ms per char)
- Blinking cursor `▊` follows text stream
- Smooth auto-scroll to keep active content visible

**Model Selection:**
- Dropdown opens downward, terminal-style list
- Keyboard navigation (arrow keys, Enter to select)
- Shows provider icon/initial + model name

**Processing States:**
- Stage-by-stage sequential reveal
- Previous stages remain visible, scrollable
- Clear "now processing" indicator on active stage
- No percentage loaders - use spinner characters

**Error Handling:**
- Red `✗` prefix for errors
- Error message in same monospace font
- Stack trace-style formatting for details

---

## Accessibility

- High contrast ratios (minimum 7:1 for terminal aesthetic)
- All interactive elements keyboard accessible
- ARIA labels for model selectors: "LLM for Stage 1"
- Screen reader announcements for stage completion
- Focus indicators always visible

---

## Key Layout Specifications

```
┌─────────────────────────────────────────┐
│ [1] GPT-4 ▾  [2] Claude ▾  [3] Gemini ▾ │ ← Fixed header (h-16)
│                           [4] GPT-5 ▾   │
├─────────────────────────────────────────┤
│                                         │
│ > STAGE [1]: GPT-4                      │
│ ─────────────────────────────────────── │
│ [Response content...]                   │ ← Scrollable area
│ ─────────────────────────────────────── │    (flex-1 overflow-auto)
│                                         │
│ > STAGE [2]: Claude Sonnet              │
│ ⣾ Processing...                         │
│                                         │
├─────────────────────────────────────────┤
│ $ Enter your query here_                │ ← Fixed input (h-20)
└─────────────────────────────────────────┘
```

**No Images:** This is a pure terminal interface - no hero images, no decorative graphics.