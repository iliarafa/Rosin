import { type StageOutput, type VerificationSummary } from "@shared/schema";

// ── Local-only PDF Report Generator ──────────────────────────────────
// Builds a styled HTML document and opens the browser's print dialog
// for PDF export. 100% local — no data leaves the device, no server calls.
// Uses monospace fonts and green accents to match the terminal aesthetic.

function esc(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** Score color as CSS hex */
function scoreHex(score: number): string {
  if (score >= 80) return "#22c55e";
  if (score >= 50) return "#eab308";
  return "#ef4444";
}

/** Change type color as CSS hex */
function changeTypeHex(ct: string): string {
  switch (ct) {
    case "added": return "#22c55e";
    case "modified": return "#60a5fa";
    case "corrected": return "#eab308";
    case "flagged": return "#ef4444";
    default: return "#888";
  }
}

/** Change type icon glyph */
function changeTypeIcon(ct: string): string {
  switch (ct) {
    case "added": return "+";
    case "modified": return "↔";
    case "corrected": return "✓";
    case "flagged": return "⚠";
    default: return "·";
  }
}

/** Severity color as CSS hex */
function severityHex(sev: string): string {
  if (sev === "high") return "#ef4444";
  if (sev === "medium") return "#eab308";
  return "#888";
}

export function generateReport(
  query: string,
  stages: StageOutput[],
  summary: VerificationSummary | null
) {
  const jv = summary?.judgeVerdict;
  const now = new Date().toLocaleString();

  // ── Build stage sections with claims, provenance, and flags ──
  const stageSections = stages.map((stage) => {
    const analysis = stage.analysis;
    let claimsHtml = "";
    let flagsHtml = "";

    if (analysis) {
      // Claims with provenance
      if (analysis.claims.length > 0) {
        const claimRows = analysis.claims.map((c) => {
          let provenanceHtml = "";
          if (c.provenance && c.provenance.length > 0) {
            const entries = c.provenance.map((p) => {
              const diffHtml = p.originalText
                ? `<div style="margin-left:24px;margin-top:2px">
                     <span style="color:#666;text-decoration:line-through">${esc(p.originalText)}</span><br>
                     <span style="color:#22c55e">${esc(p.newText)}</span>
                   </div>`
                : "";
              return `<div style="margin-top:4px">
                <span style="color:${changeTypeHex(p.changeType)}">${changeTypeIcon(p.changeType)}</span>
                <span style="color:${changeTypeHex(p.changeType)};border:1px solid ${changeTypeHex(p.changeType)}40;padding:0 4px;font-size:9px">S${p.stage} ${esc(p.model)}</span>
                <span style="color:${changeTypeHex(p.changeType)};font-size:9px;text-transform:uppercase;font-weight:600">${esc(p.changeType)}</span>
                ${diffHtml}
                <div style="color:#888;font-style:italic;font-size:9px;margin-left:24px">${esc(p.reason)}</div>
              </div>`;
            }).join("");
            provenanceHtml = `<div style="margin-left:24px;margin-top:4px;border-left:1px solid #333;padding-left:8px">${entries}</div>`;
          }
          return `<div style="margin-bottom:8px">
            <span style="color:${scoreHex(c.confidence)}">[${c.confidence}]</span>
            <span style="color:#ccc">${esc(c.text)}</span>
            ${provenanceHtml}
          </div>`;
        }).join("");
        claimsHtml = `<div style="margin-top:8px">${claimRows}</div>`;
      }

      // Hallucination flags
      if (analysis.hallucinationFlags.length > 0) {
        const flagRows = analysis.hallucinationFlags.map((f) =>
          `<div style="margin-bottom:4px">
            <span style="color:${severityHex(f.severity)}">[${f.severity.toUpperCase()}]</span>
            <span style="color:#ccc">${esc(f.claim)} — ${esc(f.reason)}</span>
          </div>`
        ).join("");
        flagsHtml = `<div style="margin-top:8px;color:#ef4444;font-weight:600;font-size:10px">FLAGGED:</div>${flagRows}`;
      }
    }

    const scoreHtml = analysis
      ? `<span style="color:${scoreHex(analysis.agreementScore)};border:1px solid ${scoreHex(analysis.agreementScore)}40;padding:1px 6px;font-size:10px;float:right">${analysis.agreementScore}</span>`
      : "";

    return `<div class="stage">
      <div class="stage-header">
        STAGE ${stage.stage}: ${esc(stage.model.provider.toUpperCase())} / ${esc(stage.model.model)}
        ${scoreHtml}
      </div>
      <div class="stage-content">${esc(stage.content)}</div>
      ${claimsHtml}
      ${flagsHtml}
    </div>`;
  }).join("");

  // ── Judge verdict section ──
  let judgeHtml = "";
  if (jv) {
    const findings = jv.keyFindings.map((f) =>
      `<div style="margin-bottom:4px"><span style="color:#22c55e80">›</span> ${esc(f)}</div>`
    ).join("");

    const stageScores = jv.stageAnalyses.map((sa) =>
      `<span style="color:${scoreHex(sa.agreementScore)};border:1px solid ${scoreHex(sa.agreementScore)}40;padding:1px 6px;margin-right:6px;font-size:10px">S${sa.stage}:${sa.agreementScore}</span>`
    ).join("");

    judgeHtml = `
      <div class="judge">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
          <span style="color:#22c55e;font-weight:bold;font-size:12px">JUDGE VERDICT</span>
          <span style="color:${scoreHex(jv.overallScore)};font-size:14px;font-weight:bold">${jv.overallScore}/100</span>
        </div>
        <div style="color:#ddd;margin-bottom:12px">${esc(jv.verdict)}</div>
        <div style="margin-bottom:8px">${findings}</div>
        <div style="margin-top:8px"><span style="color:#888">STAGES: </span>${stageScores}</div>
      </div>`;
  }

  // ── Summary section ──
  let summaryHtml = "";
  if (summary) {
    summaryHtml = `
      <div class="summary">
        <div style="color:#22c55e;font-weight:bold;font-size:11px;margin-bottom:8px">VERIFICATION SUMMARY</div>
        <div><span style="color:#888">Consistency:</span> ${esc(summary.consistency)}</div>
        <div><span style="color:#888">Hallucinations:</span> ${esc(summary.hallucinations)}</div>
        <div><span style="color:#888">Confidence:</span> ${esc(summary.confidence)}</div>
        ${summary.confidenceScore !== undefined
          ? `<div style="margin-top:6px;height:4px;background:#222;border-radius:2px"><div style="height:100%;width:${Math.round(summary.confidenceScore * 100)}%;background:${scoreHex(summary.confidenceScore * 100)};border-radius:2px"></div></div>`
          : ""}
      </div>`;
  }

  // ── Full HTML document ──
  const html = `<!DOCTYPE html>
<html>
<head>
  <title>Rosin AI — Verification Report</title>
  <style>
    @page { size: A4; margin: 24mm 20mm; }
    * { box-sizing: border-box; }
    body {
      font-family: 'SF Mono', 'Menlo', 'Courier New', monospace;
      font-size: 10px;
      line-height: 1.6;
      color: #ddd;
      background: #0f0f0f;
      padding: 40px;
      max-width: 800px;
      margin: 0 auto;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .header {
      border-bottom: 2px solid #22c55e40;
      padding-bottom: 16px;
      margin-bottom: 20px;
    }
    .header h1 {
      font-size: 16px;
      color: #22c55e;
      margin: 0 0 8px 0;
      letter-spacing: 2px;
    }
    .header .meta {
      font-size: 9px;
      color: #888;
    }
    .query-box {
      background: #1a1a1a;
      border-left: 3px solid #22c55e40;
      padding: 12px 16px;
      margin: 16px 0;
    }
    .query-box .label { color: #888; font-size: 9px; }
    .query-box .text { color: #eee; margin-top: 4px; }
    .judge {
      background: #1a1a1a;
      border: 1px solid #22c55e30;
      padding: 16px;
      margin: 20px 0;
    }
    .stage {
      margin: 20px 0;
      padding: 12px 16px;
      border-left: 3px solid #333;
      page-break-inside: avoid;
    }
    .stage-header {
      font-weight: bold;
      color: #aaa;
      font-size: 10px;
      margin-bottom: 8px;
    }
    .stage-content {
      white-space: pre-wrap;
      word-wrap: break-word;
      color: #ccc;
    }
    .verified {
      margin-top: 24px;
      padding: 16px;
      border: 1px solid #22c55e30;
      background: #0d1f0d;
    }
    .verified .label {
      color: #22c55e;
      font-weight: bold;
      font-size: 11px;
      margin-bottom: 8px;
    }
    .verified .content {
      white-space: pre-wrap;
      word-wrap: break-word;
      color: #ddd;
    }
    .summary {
      margin-top: 20px;
      padding: 16px;
      border-top: 2px solid #22c55e30;
    }
    .footer {
      margin-top: 30px;
      padding-top: 12px;
      border-top: 1px solid #333;
      text-align: center;
      color: #555;
      font-size: 8px;
    }
    @media print {
      body { padding: 0; background: #0f0f0f; }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>ROSIN AI — VERIFICATION REPORT</h1>
    <div class="meta">${esc(now)} • ${stages.length} stages • Generated 100% locally</div>
  </div>

  <div class="query-box">
    <div class="label">QUERY</div>
    <div class="text">${esc(query)}</div>
  </div>

  ${judgeHtml}

  ${stageSections}

  ${stages.length > 0 ? `
    <div class="verified">
      <div class="label">FINAL VERIFIED ANSWER</div>
      <div class="content">${esc(stages[stages.length - 1].content)}</div>
    </div>
  ` : ""}

  ${summaryHtml}

  <div class="footer">
    Generated 100% locally on device • No data was collected or sent • Private
  </div>
</body>
</html>`;

  // Open in a new window and trigger print (browser PDF dialog)
  const printWindow = window.open("", "_blank");
  if (printWindow) {
    printWindow.document.write(html);
    printWindow.document.close();
    printWindow.onload = () => printWindow.print();
  }
}
