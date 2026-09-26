import { spawnSync } from "node:child_process";
import {
  accessSync,
  constants,
  mkdirSync,
  readFileSync,
  rmSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const changelogUrl = "https://developers.openai.com/codex/changelog?surface=cli";
const versionPattern = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
const categoryNames = new Map([
  ["new features", "新機能"],
  ["improvements", "改善"],
  ["performance improvements", "性能改善"],
  ["bug fixes", "不具合修正"],
  ["security", "セキュリティ"],
  ["breaking changes", "互換性に関わる変更"],
  ["deprecations", "廃止予定"],
  ["documentation", "文書"],
  ["chores", "その他の変更"],
]);

function cleanVersion(value) {
  return typeof value === "string" && versionPattern.test(value) ? value : "";
}

function findCodexBinary() {
  const candidates = [join(process.env.HOME ?? "", ".local", "bin", "codex")];
  for (const directory of (process.env.PATH ?? "").split(":")) {
    if (directory) candidates.push(join(directory, "codex"));
  }

  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      // 実行できる候補だけを使う。
    }
  }
  return "";
}

function installedVersion() {
  const binary = findCodexBinary();
  if (!binary) return "";
  try {
    const result = spawnSync(binary, ["--version"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 5000,
      env: { ...process.env, CODEX_UPDATE_SUMMARY_SKIP: "1" },
    });
    if (result.status !== 0) return "";
    const output = result.stdout ?? "";
    const match = output.match(/\bcodex-cli\s+([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)/i);
    return cleanVersion(match?.[1] ?? "");
  } catch {
    return "";
  }
}

function statePath() {
  const configured = process.env.XDG_STATE_HOME;
  const base = configured?.startsWith("/")
    ? configured
    : join(process.env.HOME ?? "", ".local", "state");
  return join(base, "codex-update-summary", "last-version");
}

function readPreviousVersion(path) {
  try {
    return cleanVersion(readFileSync(path, "utf8").trim());
  } catch {
    return "";
  }
}

function saveVersion(path, version) {
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const temporaryPath = `${path}.${process.pid}.tmp`;
  writeFileSync(temporaryPath, `${version}\n`, { mode: 0o600 });
  renameSync(temporaryPath, path);
}

function htmlToText(html) {
  return html
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<li\b[^>]*>/gi, "\n- ")
    .replace(/<br\b[^>]*>/gi, "\n")
    .replace(/<\/(?:h[1-6]|p|li|div|pre|section|blockquote|ul|ol)\s*>/gi, "\n")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;|&#160;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&#x27;/gi, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_match, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&#([0-9]+);/g, (_match, code) => String.fromCodePoint(Number.parseInt(code, 10)));
}

function releaseNotesFromBlock(block, version) {
  const lines = htmlToText(block)
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);
  const notes = [];
  let category = "";
  let releaseSummaryUnavailable = false;

  for (const line of lines) {
    const categoryName = categoryNames.get(line.toLowerCase());
    if (categoryName) {
      category = categoryName;
      continue;
    }
    if (/release highlights could not be determined/i.test(line)) {
      releaseSummaryUnavailable = true;
      continue;
    }
    if (
      !category ||
      /^codex cli\b/i.test(line) ||
      /^\d{4}-\d{2}-\d{2}$/.test(line) ||
      /^\$?\s*npm\s+install\b/i.test(line) ||
      /^view details$/i.test(line) ||
      /^changelog$/i.test(line) ||
      /^full changelog:/i.test(line) ||
      /^full release on github$/i.test(line) ||
      /^[-#]+$/.test(line)
    ) {
      continue;
    }

    const note = line.replace(/^-\s*/, "").trim();
    if (!note) continue;
    const previous = notes.at(-1);
    if (line.startsWith("- ") || !previous) {
      notes.push(`${category}: ${note}`);
    } else {
      notes[notes.length - 1] = `${previous} ${note}`;
    }
  }

  if (releaseSummaryUnavailable && notes.length === 0) {
    notes.push("公式変更履歴にこの版のリリース要約は掲載されていません。");
  }
  return { version, notes };
}

export function extractReleaseNotes(html, previousVersion, currentVersion) {
  const entries = [];
  const entryPattern = /(<li\b[^>]*data-codex-topics="codex-cli"[^>]*>)([\s\S]*?)(?=<li\b[^>]*data-codex-topics="codex-cli"|<\/main>)/gi;
  let collecting = false;
  let previousFound = false;
  let currentFound = false;
  let match;
  const releaseLinks = [];

  while ((match = entryPattern.exec(html)) !== null) {
    const openingTag = match[1];
    const block = `${openingTag}${match[2]}`;
    const text = htmlToText(block);
    const versionMatch = text.match(/\bCodex CLI\s+([vV]?\d+(?:\.\d+){1,3})\b/);
    const version = cleanVersion(versionMatch?.[1]?.replace(/^[vV]/, "") ?? "");
    if (!version) continue;

    if (!collecting) {
      if (version !== currentVersion) continue;
      collecting = true;
      currentFound = true;
    } else if (version === previousVersion) {
      previousFound = true;
      break;
    }

    const parsed = releaseNotesFromBlock(match[2], version);
    if (parsed.notes.length > 0) entries.push(parsed);
    const anchor = openingTag.match(/\bid="([^"]+)"/i)?.[1];
    if (anchor) releaseLinks.push(`${changelogUrl.split("?")[0]}#${anchor}`);
  }

  const notes = entries.flatMap((entry) => entry.notes.map((note) => `${entry.version}: ${note}`));
  return {
    currentFound,
    previousFound,
    notes: notes.slice(0, 24),
    releaseLinks: releaseLinks.slice(0, 8),
  };
}

function readSafeUsageProfile() {
  const codexHome = process.env.CODEX_HOME || join(process.env.HOME ?? "", ".codex");
  let config = "";
  try {
    config = readFileSync(join(codexHome, "config.toml"), "utf8");
  } catch {
    return ["- Codex CLI を端末から利用しています。", "- 人が読む案内は日本語にします。"];
  }

  const lastString = (key) => {
    const pattern = new RegExp(`^\\s*${key}\\s*=\\s*"([^"\\n]*)"`, "gm");
    const matches = [...config.matchAll(pattern)];
    return matches.at(-1)?.[1] ?? "";
  };
  const model = lastString("model");
  const reasoning = lastString("model_reasoning_effort");
  const statusLineMatch = [...config.matchAll(/status_line\s*=\s*\[([^\]]*)\]/g)].at(-1);
  const statusLine = [...(statusLineMatch?.[1] ?? "").matchAll(/"([^"]+)"/g)].map((item) => item[1]);
  const profile = ["- Codex CLI を端末から利用し、人が読む案内は日本語にします。"];
  if (model) profile.push(`- 既定モデルは ${model}${reasoning ? `、推論の強さは ${reasoning}` : ""} です。`);

  const statusNames = new Map([
    ["context-remaining", "コンテキスト残量"],
    ["five-hour-limit", "5 時間の利用枠"],
    ["weekly-limit", "週ごとの利用枠"],
    ["model-with-reasoning", "モデルと推論の強さ"],
    ["project-name", "プロジェクト名"],
    ["git-branch", "Git ブランチ"],
  ]);
  const visibleStatus = statusLine.map((name) => statusNames.get(name) ?? name);
  if (visibleStatus.length) profile.push(`- ステータス欄には ${visibleStatus.join("、")} を表示します。`);
  if (/raw_output_mode\s*=\s*false/.test(config)) {
    profile.push("- 通常表示を使い、必要なときだけ raw 表示に切り替えます。");
  }
  if (config.includes("agent-notify.sh") && config.includes("PermissionRequest")) {
    profile.push("- 許可待ちをデスクトップ通知で知らせます。");
  }
  if (/\[plugins\."interview-dev-loop@interview-dev-loop"\][\s\S]*?enabled\s*=\s*true/.test(config)) {
    profile.push("- interview-dev-loop を使い、確認と計画を経てから実装する進め方を利用します。");
  }
  return profile;
}

function buildPrompt(previousVersion, currentVersion, result) {
  const notes = result.notes.length
    ? result.notes.map((note) => `- ${note}`).join("\n")
    : "公式変更履歴から対象版の具体的な変更点を確認できませんでした。変更内容を推測しないでください。";
  const links = result.releaseLinks.length ? result.releaseLinks.join("\n") : changelogUrl;
  const gap = result.previousFound
    ? ""
    : `\n前回版 ${previousVersion} の項目が変更履歴上で見つからない場合、確認できた範囲だけを説明してください。`;

  return [
    "Codex CLI の更新後に表示する、短い日本語の案内を書いてください。",
    `更新前: ${previousVersion}`,
    `更新後: ${currentVersion}`,
    "公式変更履歴から抽出した内容:",
    notes,
    "公式リンク:",
    links,
    "このユーザーの設定と使い方:",
    ...readSafeUsageProfile(),
    "出力条件:",
    "- 変更内容を最大 4 点に絞り、各項目にこのユーザーにとっての利点または影響を書く。",
    "- 設定に直接関係する点を先にし、関係が薄い変更は省く。直接関係する点がなければ、そのことを明記する。",
    "- 公式変更履歴にない動作や利点を推測しない。確認できない点は確認できないと書く。",
    "- 5〜8 行程度で簡潔にまとめ、最後に公式リンクを付ける。",
    gap,
  ].join("\n");
}

async function fetchReleaseNotes(previousVersion, currentVersion) {
  try {
    const response = await fetch(changelogUrl, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) return { notes: [], releaseLinks: [], currentFound: false, previousFound: false };
    const html = await response.text();
    return extractReleaseNotes(html, previousVersion, currentVersion);
  } catch {
    return { notes: [], releaseLinks: [], currentFound: false, previousFound: false };
  }
}

function runSummary(codexBinary, prompt) {
  const workingDirectory = join(tmpdir(), `codex-update-summary-${process.pid}`);
  try {
    mkdirSync(workingDirectory, { recursive: true, mode: 0o700 });
    const result = spawnSync(
      codexBinary,
      [
        "exec",
        "--ephemeral",
        "--sandbox",
        "read-only",
        "--skip-git-repo-check",
        "--cd",
        workingDirectory,
        prompt,
      ],
      {
        encoding: "utf8",
        timeout: 70000,
        maxBuffer: 1024 * 1024,
        env: { ...process.env, CODEX_UPDATE_SUMMARY_SKIP: "1" },
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
    if (result.status !== 0) return "";
    return (result.stdout ?? "").trim().slice(0, 5000);
  } catch {
    return "";
  } finally {
    try {
      rmSync(workingDirectory, { recursive: true, force: true });
    } catch {
      // 一時作業領域を削除できなくても Codex の起動は続ける。
    }
  }
}

export async function handleSessionStart(event) {
  if (process.env.CODEX_UPDATE_SUMMARY_SKIP === "1") return;
  if (event.hook_event_name !== "SessionStart" || !["startup", "resume"].includes(event.source)) return;

  const currentVersion = installedVersion();
  if (!currentVersion) return;

  const path = statePath();
  const previousVersion = readPreviousVersion(path);
  if (!previousVersion) {
    try {
      saveVersion(path, currentVersion);
    } catch {
      // 状態を書き込めない端末では、フックを失敗扱いにしない。
    }
    return;
  }
  if (previousVersion === currentVersion) return;

  const releaseNotes = await fetchReleaseNotes(previousVersion, currentVersion);
  const prompt = buildPrompt(previousVersion, currentVersion, releaseNotes);
  const codexBinary = findCodexBinary();
  const hasDetailedNotes = releaseNotes.notes.some(
    (note) => !note.includes("公式変更履歴にこの版のリリース要約は掲載されていません。"),
  );
  const summary = codexBinary && hasDetailedNotes ? runSummary(codexBinary, prompt) : "";

  try {
    saveVersion(path, currentVersion);
  } catch {
    // 要約の重複を避けるため、保存に失敗しても今回の案内は表示する。
  }

  if (summary) {
    return { systemMessage: `Codex CLI を ${previousVersion} から ${currentVersion} に更新しました。\n\n${summary}` };
  }

  const fallbackDetails = releaseNotes.notes.length
    ? releaseNotes.notes.map((note) => `- ${note}`).join("\n")
    : "公式変更履歴を取得できず、変更内容は未確認です。";
  const fallbackReason = hasDetailedNotes
    ? "変更点は確認できましたが、日本語要約を生成できませんでした。"
    : "公式変更履歴に詳細がないため、使い方への影響は判断できませんでした。";
  const response = {
    systemMessage: `Codex CLI の版が ${previousVersion} から ${currentVersion} に変わりました。\n${fallbackReason}\n${fallbackDetails}\n公式変更履歴: ${changelogUrl}`,
  };
  if (hasDetailedNotes) {
    response.hookSpecificOutput = {
      hookEventName: "SessionStart",
      additionalContext: prompt,
    };
  }
  return response;
}

async function main() {
  if (process.env.CODEX_UPDATE_SUMMARY_SKIP === "1") return;
  let event;
  try {
    event = JSON.parse(readFileSync(0, "utf8"));
  } catch {
    return;
  }
  const response = await handleSessionStart(event);
  if (response) process.stdout.write(`${JSON.stringify(response)}\n`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
