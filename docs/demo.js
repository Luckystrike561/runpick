"use strict";

const DEVBOX_SCRIPTS = [
  { name: "build", steps: ["echo 'compiling...' && sleep 1 && echo 'built dist/app'"] },
  { name: "test", steps: ["echo 'running 42 tests'", "sleep 1", "echo 'all green'"] },
  { name: "lint", steps: ["echo 'no issues found'"] },
  { name: "db:migrate", steps: ["echo 'applied 3 migrations'"] },
  { name: "db:seed", steps: ["echo 'seeded 100 rows'"] },
  { name: "release", steps: ["echo 'tagging v1.2.0'", "echo 'pushed'"] },
];

const NPM_SCRIPTS = [
  { name: "build", preview: "vite build", steps: ["echo 'vite v5.4.2 building for production...'" , "sleep 1", "echo 'built dist in 812ms'"] },
  { name: "test", preview: "vitest run", steps: ["echo 'RUN  v1.6.0'" , "sleep 1", "echo 'Test Files  3 passed (3)'", "echo 'Tests  42 passed (42)'"] },
  { name: "lint", preview: "eslint .", steps: ["echo 'no lint errors'"] },
  { name: "dev:web", preview: "vite", steps: ["echo 'VITE ready in 231ms'", "echo 'Local: http://localhost:5173/'" ] },
  { name: "dev:api", preview: "node server.js", steps: ["echo 'api listening on :3000'"] },
  { name: "release", preview: "changeset publish", steps: ["echo 'Publishing runpick@1.2.0...'", "sleep 1", "echo 'Published'" ] },
];

const PICK_DEVBOX = "devbox run pick";
const PICK_NPM = "devbox run pick:npm";
const RUNNERS = {
  devbox: { command: PICK_DEVBOX, prompt: "devbox run ", scripts: DEVBOX_SCRIPTS, npm: false },
  npm: { command: PICK_NPM, prompt: "npm run ", scripts: NPM_SCRIPTS, npm: true },
};

const PREVIEW_HEIGHT_LINES = 4;
const MAX_PREVIEW_WIDTH_CHARS = 56;
const PREVIEW_FRAME_CHARS = 4;
const MONO_ADVANCE_EM = 0.6;
const TYPING_DELAY_MS = 70;
const AUTOPLAY_RESTART_DELAY_MS = 4000;
const MAX_HISTORY_LINES = 200;

const terminal = document.getElementById("terminal");

const state = {
  history: [],
  mode: "shell",
  runner: "devbox",
  shellInput: "",
  query: "",
  cursorIndex: 0,
  isUserDriven: false,
  generation: 0,
};

function runner() {
  return RUNNERS[state.runner];
}

function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}

function fuzzyMatch(name, query) {
  if (!query) return { score: 0, positions: [] };
  const haystack = name.toLowerCase();
  const positions = [];
  let from = 0;
  for (const char of query.toLowerCase()) {
    const at = haystack.indexOf(char, from);
    if (at === -1) return null;
    positions.push(at);
    from = at + 1;
  }
  const span = positions[positions.length - 1] - positions[0];
  const startBonus = positions[0] === 0 ? 10 : 0;
  return { score: 100 - span - positions[0] + startBonus, positions };
}

function filteredScripts() {
  const scripts = runner().scripts;
  return scripts
    .map((script, order) => ({ script, order, match: fuzzyMatch(script.name, state.query) }))
    .filter((entry) => entry.match)
    .sort((a, b) => b.match.score - a.match.score || a.order - b.order);
}

function highlight(name, positions) {
  return [...name]
    .map((char, i) => (positions.includes(i) ? `<span class="term-match">${escapeHtml(char)}</span>` : escapeHtml(char)))
    .join("");
}

function cursorHtml() {
  const userClass = state.isUserDriven ? " is-user" : "";
  return `<span class="cursor${userClass}"> </span>`;
}

function previewText(script) {
  return script.preview ?? script.steps.join("\n");
}

function wrapPreview(command, widthChars) {
  const lines = [];
  for (const raw of command.split("\n")) {
    for (let i = 0; i < raw.length || i === 0; i += widthChars) {
      lines.push(raw.slice(i, i + widthChars));
    }
  }
  return lines;
}

function pickerLines(columns) {
  const scripts = runner().scripts;
  const previewWidthChars = Math.min(MAX_PREVIEW_WIDTH_CHARS, columns - PREVIEW_FRAME_CHARS);
  const entries = filteredScripts();
  state.cursorIndex = Math.min(state.cursorIndex, Math.max(entries.length - 1, 0));
  const lines = [
    `<span class="term-fzf-prompt">${escapeHtml(runner().prompt)}</span>${escapeHtml(state.query)}${cursorHtml()}`,
    `<span class="term-info">  ${entries.length}/${scripts.length} ${"─".repeat(Math.min(40, columns - 8))}</span>`,
  ];
  entries.forEach((entry, i) => {
    const isCurrent = i === state.cursorIndex;
    const pointer = isCurrent ? '<span class="term-pointer">▌</span> ' : "  ";
    const classes = isCurrent ? "term-item term-current" : "term-item";
    lines.push(`<span class="${classes}" data-index="${i}">${pointer}${highlight(entry.script.name, entry.match.positions)}</span>`);
  });
  const current = entries[state.cursorIndex];
  const preview = current ? wrapPreview(previewText(current.script), previewWidthChars) : [];
  const border = "─".repeat(previewWidthChars + 2);
  lines.push(`<span class="term-border">╭${border}╮</span>`);
  for (let i = 0; i < PREVIEW_HEIGHT_LINES; i++) {
    const text = (preview[i] || "").padEnd(previewWidthChars);
    lines.push(`<span class="term-border">│</span> <span class="term-preview">${escapeHtml(text)}</span> <span class="term-border">│</span>`);
  }
  lines.push(`<span class="term-border">╰${border}╯</span>`);
  return lines;
}

function shellPromptHtml(input) {
  return `<span class="term-prompt">~/myapp $</span> ${escapeHtml(input)}`;
}

function render() {
  if (terminal.hidden) return;
  const style = getComputedStyle(terminal);
  const innerWidthPx = terminal.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
  const innerHeightPx = terminal.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom);
  const columns = Math.floor(innerWidthPx / (parseFloat(style.fontSize) * MONO_ADVANCE_EM));
  const visibleRows = Math.max(Math.floor(innerHeightPx / parseFloat(style.lineHeight)), 1);
  const lines = [...state.history];
  if (state.mode === "shell") lines.push(`${shellPromptHtml(state.shellInput)}${cursorHtml()}`);
  if (state.mode === "picker") lines.push(...pickerLines(columns));
  terminal.innerHTML = lines.slice(-visibleRows).map((html) => `<div class="line">${html}</div>`).join("");
}

function pushHistory(html) {
  state.history.push(html);
  if (state.history.length > MAX_HISTORY_LINES) state.history.splice(0, state.history.length - MAX_HISTORY_LINES);
}

function sleep(ms, generation) {
  return new Promise((resolve, reject) => {
    setTimeout(() => (generation === state.generation ? resolve() : reject(new Error("superseded"))), ms);
  });
}

function parseSleepSeconds(command) {
  const match = command.match(/^sleep\s+(\d+(?:\.\d+)?)$/);
  return match ? Number(match[1]) : null;
}

function parseEcho(command) {
  const match = command.match(/^echo\s+'([^']*)'$/);
  return match ? match[1] : null;
}

async function runScript(entry, generation) {
  if (runner().npm) {
    pushHistory(`<span class="term-info">&gt; ${escapeHtml(entry.script.name)}</span>`);
    pushHistory(`<span class="term-info">&gt; ${escapeHtml(entry.script.preview)}</span>`);
    pushHistory("");
  }
  const commands = entry.script.steps.flatMap((step) => step.split("&&").map((part) => part.trim()));
  for (const command of commands) {
    const seconds = parseSleepSeconds(command);
    if (seconds !== null) {
      await sleep(seconds * 1000, generation);
      continue;
    }
    const output = parseEcho(command);
    if (output !== null) pushHistory(escapeHtml(output));
    render();
  }
}

function openPicker(command, runnerName) {
  pushHistory(shellPromptHtml(command));
  state.runner = runnerName;
  state.shellInput = "";
  state.query = "";
  state.cursorIndex = 0;
  state.mode = "picker";
  render();
}

function returnToShell() {
  state.mode = "shell";
  if (state.isUserDriven) state.shellInput = runner().command;
  render();
}

async function acceptSelection(generation) {
  const entry = filteredScripts()[state.cursorIndex];
  if (!entry) return;
  state.mode = "running";
  render();
  try {
    await runScript(entry, generation);
  } finally {
    if (generation === state.generation) returnToShell();
  }
}

function moveCursor(delta) {
  const count = filteredScripts().length;
  if (count === 0) return;
  state.cursorIndex = (state.cursorIndex + delta + count) % count;
  render();
}

async function typeInto(field, text, generation) {
  for (const char of text) {
    state[field] += char;
    if (field === "query") state.cursorIndex = 0;
    render();
    await sleep(TYPING_DELAY_MS, generation);
  }
}

async function autoplay(generation) {
  const pause = (ms) => sleep(ms, generation);
  await pause(800);
  await typeInto("shellInput", PICK_DEVBOX, generation);
  await pause(400);
  openPicker(PICK_DEVBOX, "devbox");
  await pause(1500);
  moveCursor(1);
  await pause(700);
  moveCursor(1);
  await pause(700);
  moveCursor(-1);
  await pause(700);
  await typeInto("query", "db", generation);
  await pause(900);
  await typeInto("query", ":m", generation);
  await pause(1100);
  await acceptSelection(generation);
  await pause(1800);
  await typeInto("shellInput", PICK_NPM, generation);
  await pause(400);
  openPicker(PICK_NPM, "npm");
  await pause(1500);
  await typeInto("query", "build", generation);
  await pause(1100);
  await acceptSelection(generation);
  await pause(AUTOPLAY_RESTART_DELAY_MS);
  state.history = [];
  state.runner = "devbox";
  render();
  autoplay(generation).catch(() => {});
}

function takeOver() {
  if (state.isUserDriven) return;
  state.isUserDriven = true;
  state.generation += 1;
  state.history = [];
  state.mode = "shell";
  state.shellInput = runner().command;
  render();
}

function handleShellKey(event) {
  if (event.key === "Enter") {
    const typed = state.shellInput.trim();
    if (typed === PICK_DEVBOX || typed === PICK_NPM) {
      openPicker(typed, typed === PICK_NPM ? "npm" : "devbox");
      return;
    }
    pushHistory(shellPromptHtml(state.shellInput));
    if (typed) pushHistory(`try: ${escapeHtml(PICK_DEVBOX)} or ${escapeHtml(PICK_NPM)}`);
    state.shellInput = "";
  } else if (event.key === "Backspace") {
    state.shellInput = state.shellInput.slice(0, -1);
  } else if (event.key === "c" && event.ctrlKey) {
    pushHistory(`${shellPromptHtml(state.shellInput)}^C`);
    state.shellInput = "";
  } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey) {
    state.shellInput += event.key;
  } else {
    return;
  }
  render();
}

function handlePickerKey(event) {
  const isCtrl = event.ctrlKey;
  if (event.key === "Enter") {
    acceptSelection(state.generation).catch(() => {});
  } else if (event.key === "Escape" || (isCtrl && event.key === "c")) {
    returnToShell();
  } else if (event.key === "ArrowDown" || (isCtrl && (event.key === "n" || event.key === "j"))) {
    moveCursor(1);
  } else if (event.key === "ArrowUp" || (isCtrl && (event.key === "p" || event.key === "k"))) {
    moveCursor(-1);
  } else if (event.key === "Backspace") {
    state.query = state.query.slice(0, -1);
    state.cursorIndex = 0;
    render();
  } else if (event.key.length === 1 && !isCtrl && !event.metaKey) {
    state.query += event.key;
    state.cursorIndex = 0;
    render();
  }
}

terminal.addEventListener("keydown", (event) => {
  if (event.metaKey || event.altKey) return;
  takeOver();
  event.preventDefault();
  if (state.mode === "shell") handleShellKey(event);
  else if (state.mode === "picker") handlePickerKey(event);
});

terminal.addEventListener("pointerdown", takeOver);

terminal.addEventListener("click", (event) => {
  const item = event.target.closest(".term-item");
  if (!item || state.mode !== "picker") return;
  state.cursorIndex = Number(item.dataset.index);
  acceptSelection(state.generation).catch(() => {});
});

for (const tab of document.querySelectorAll(".terminal-tab")) {
  tab.addEventListener("click", () => {
    const view = tab.dataset.view;
    for (const other of document.querySelectorAll(".terminal-tab")) other.classList.toggle("is-active", other === tab);
    terminal.hidden = view !== "live";
    for (const image of document.querySelectorAll(".recording")) image.hidden = image.dataset.view !== view;
    render();
  });
}

for (const button of document.querySelectorAll(".copy")) {
  button.addEventListener("click", async () => {
    const text = button.dataset.copy ?? button.parentElement.querySelector("code").textContent;
    await navigator.clipboard.writeText(text);
    button.textContent = "copied";
    button.classList.add("is-copied");
    setTimeout(() => {
      button.textContent = "copy";
      button.classList.remove("is-copied");
    }, 1500);
  });
}

window.addEventListener("resize", render);
render();
autoplay(state.generation).catch(() => {});
