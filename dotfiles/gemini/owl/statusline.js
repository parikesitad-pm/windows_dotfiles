#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(__dirname, 'statusline_state.json');

function formatTokens(n) {
  if (!n || n <= 0) return '0';
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'm';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
  return String(n);
}

function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return '0m';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) {
    return `${h}j ${m}m`;
  }
  return `${m}m`;
}

function cleanModelName(display, id) {
  const raw = display || id || 'Gemini 3.8 Flash (High)';
  // Extracts base model name e.g. "Gemini 3.8", "Claude 3.5 Sonnet", "Gemini 3.1 Pro"
  const m = raw.match(/([a-zA-Z]+\s+\d+(?:\.\d+)?(?:\s+[a-zA-Z]+)?)/);
  if (m) {
    return m[1].replace(/\s+(Flash|High|Medium|Low)$/i, '').trim();
  }
  return raw.split(' ')[0] || 'Gemini 3.8';
}

function cleanEffort(effort, rawDisplay) {
  if (effort && typeof effort === 'string') return effort.toLowerCase();
  const text = (rawDisplay || '').toLowerCase();
  if (text.includes('high')) return 'high';
  if (text.includes('medium') || text.includes('med')) return 'medium';
  if (text.includes('low')) return 'low';
  if (text.includes('thinking')) return 'thinking';
  return 'high';
}

let input = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', chunk => {
  input += chunk;
});

process.stdin.on('end', () => {
  let data = {};
  if (input.trim()) {
    try {
      data = JSON.parse(input);
    } catch (e) {}
  }

  // Load / persist state
  let state = {};
  try {
    if (fs.existsSync(STATE_FILE)) {
      state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    }
  } catch (e) {}

  // 1. Tokens and Context %
  let totalTokens = 0;
  let contextSize = 1048576;
  let usedPct = 0;

  if (data.context_window) {
    const inp = data.context_window.total_input_tokens || 0;
    const out = data.context_window.total_output_tokens || 0;
    totalTokens = inp + out;
    contextSize = data.context_window.context_window_size || 1048576;
    if (typeof data.context_window.used_percentage === 'number') {
      usedPct = data.context_window.used_percentage;
    } else if (contextSize > 0 && totalTokens > 0) {
      usedPct = (totalTokens / contextSize) * 100;
    }
  }

  // 2. Quota & Reset countdown
  let quotaRemainingPct = 0;
  let resetSec = 0;

  if (data.quota) {
    // Prefer gemini-5h, then 3p-5h, then first available
    const bucket = data.quota['gemini-5h'] || data.quota['3p-5h'] || Object.values(data.quota)[0];
    if (bucket) {
      if (typeof bucket.remaining_fraction === 'number') {
        quotaRemainingPct = Math.round(bucket.remaining_fraction * 100);
      }
      resetSec = bucket.reset_in_seconds || 0;
    }
  }

  const resetStr = formatDuration(resetSec || 11220); // Fallback ~3j 7m if 0
  const quotaColor = quotaRemainingPct <= 10 
    ? '\x1b[38;2;247;118;142m' // Red/Magenta
    : (quotaRemainingPct <= 35 ? '\x1b[38;2;224;175;104m' : '\x1b[38;2;158;206;106m'); // Yellow : Green

  // Update and persist state
  if (totalTokens === 0 && state.last_tokens) {
    totalTokens = state.last_tokens;
    usedPct = state.last_used_pct || ((totalTokens / contextSize) * 100);
  }

  state.last_tokens = totalTokens;
  state.last_used_pct = usedPct;
  state.tokens = totalTokens;
  state.used_pct = usedPct;
  state.quota_remaining_pct = quotaRemainingPct;
  state.reset_seconds = resetSec;
  state.reset_str = resetStr;
  state.context_size = contextSize;
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
  } catch (e) {}

  const tokStr = formatTokens(totalTokens);
  const tokPctStr = usedPct.toFixed(1);

  // 3. Model & Effort
  const rawModel = data.model ? (data.model.display_name || data.model.id) : 'Gemini 3.8 Flash (High)';
  const modelName = cleanModelName(rawModel, data.model ? data.model.id : '');
  const effort = cleanEffort(data.model ? data.model.effort : null, rawModel);

  // Colors
  const C_RESET = '\x1b[0m';
  const C_DIM = '\x1b[2m';
  const C_BOLD = '\x1b[1m';
  const C_GRAY = '\x1b[38;2;86;95;137m';
  const C_CYAN = '\x1b[38;2;125;207;255m';
  const C_YELLOW = '\x1b[38;2;224;175;104m';
  const C_MAGENTA = '\x1b[38;2;247;118;142m';
  const C_GREEN = '\x1b[38;2;158;206;106m';
  const C_WHITE = '\x1b[38;2;255;255;255m';

  // Line 1: 🦉 ⚡ 105.7k (7.4%) | 💎 0% (3j 7m)
  const line1 = `🦉 ${C_YELLOW}⚡${C_RESET} ${C_CYAN}${tokStr}${C_RESET} ${C_YELLOW}(${tokPctStr}%)${C_RESET} ${C_GRAY}|${C_RESET} 💎 ${quotaColor}${quotaRemainingPct}%${C_RESET} ${C_GRAY}(${resetStr})${C_RESET}`;

  // Line 2 (Windows version): crafted with ♥ · a Modula project by parikesitad-pm · 🧠 Gemini 3.8 Flash (High)
  const cols = process.stdout.columns || 80;
  const line2 = (cols < 78)
    ? ` ${C_GRAY}crafted with${C_RESET} ${C_MAGENTA}♥${C_RESET} ${C_GRAY}· Modula ·${C_RESET} ${C_CYAN}🧠 ${rawModel}${C_RESET}`
    : ` ${C_GRAY}crafted with${C_RESET} ${C_MAGENTA}♥${C_RESET} ${C_GRAY}· a Modula project by parikesitad-pm ·${C_RESET} ${C_CYAN}🧠 ${rawModel}${C_RESET}`;

  process.stdout.write(`${line1}\n${line2}\n`);
});
