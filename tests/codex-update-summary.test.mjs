import assert from "node:assert/strict";
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { extractReleaseNotes, handleSessionStart } from "../scripts/codex-update-summary.mjs";

function testReleaseRange() {
  const html = `
    <main>
      <li id="github-release-new" data-codex-topics="codex-cli" data-release-url="https://github.com/openai/codex/releases/tag/rust-v0.157.1">
        <h3>Codex CLI 0.157.1</h3>
        <h4>Improvements</h4>
        <ul><li>改善されたターミナル表示です。</li></ul>
      </li>
      <li id="github-release-old" data-codex-topics="codex-cli">
        <h3>Codex CLI 0.157.0</h3>
        <h4>New Features</h4>
        <ul><li>前回版だけの機能です。</li></ul>
      </li>
    </main>`;

  const result = extractReleaseNotes(html, "0.157.0", "0.157.1");

  assert.equal(result.currentFound, true);
  assert.equal(result.previousFound, true);
  assert.ok(result.notes.some((note) => note.includes("改善されたターミナル表示です。")));
  assert.ok(!result.notes.some((note) => note.includes("前回版だけの機能です。")));
}

function testMissingPreviousRelease() {
  const html = `
    <main>
      <li data-codex-topics="codex-cli">
        <h3>Codex CLI 0.157.1</h3>
        <h4>Bug Fixes</h4>
        <ul><li>一時的なエラーからの復旧を改善しました。</li></ul>
      </li>
    </main>`;

  const result = extractReleaseNotes(html, "0.150.0", "0.157.1");

  assert.equal(result.currentFound, true);
  assert.equal(result.previousFound, false);
  assert.ok(result.notes.some((note) => note.includes("一時的なエラーからの復旧")));
}

async function testVersionStateFlow() {
  const testDirectory = mkdtempSync(join(tmpdir(), "codex-update-test-"));
  const home = join(testDirectory, "利用者ホーム");
  const codexHome = join(home, ".codex");
  const binDirectory = join(home, ".local", "bin");
  const stateHome = join(home, ".local", "state");
  const promptCapture = join(testDirectory, "要約入力.txt");
  const codexPath = join(binDirectory, "codex");
  const statePath = join(stateHome, "codex-update-summary", "last-version");
  const testChangelog = `
    <main>
      <li id="github-release-new" data-codex-topics="codex-cli">
        <h3>Codex CLI 0.157.1</h3><h4>Improvements</h4>
        <ul><li>端末の表示を改善しました。</li></ul>
      </li>
      <li id="github-release-old" data-codex-topics="codex-cli">
        <h3>Codex CLI 0.157.0</h3><h4>New Features</h4>
        <ul><li>前回版の説明です。</li></ul>
      </li>
    </main>`;
  const environmentKeys = [
    "HOME",
    "CODEX_HOME",
    "XDG_STATE_HOME",
    "CODEX_TEST_VERSION",
    "CODEX_TEST_PROMPT_CAPTURE",
    "CODEX_UPDATE_SUMMARY_SKIP",
  ];
  const previousEnvironment = new Map(environmentKeys.map((key) => [key, process.env[key]]));
  const previousFetch = globalThis.fetch;

  try {
    mkdirSync(codexHome, { recursive: true });
    mkdirSync(binDirectory, { recursive: true });
    writeFileSync(
      join(codexHome, "config.toml"),
      [
        'model = "gpt-6-sol"',
        'model_reasoning_effort = "medium"',
        'status_line = ["context-remaining", "five-hour-limit"]',
        "raw_output_mode = false",
        "[[hooks.PermissionRequest]]",
        'command = \'bash "$HOME/.local/bin/agent-notify.sh" --provider codex\'',
        '[plugins."interview-dev-loop@interview-dev-loop"]',
        "enabled = true",
      ].join("\n"),
    );
    writeFileSync(
      codexPath,
      [
        "#!/usr/bin/env bash",
        'if [[ "${1:-}" == "--version" ]]; then printf "codex-cli %s\\n" "$CODEX_TEST_VERSION"; exit 0; fi',
        'if [[ "${1:-}" == "exec" ]]; then printf "%s\\n" "$@" > "$CODEX_TEST_PROMPT_CAPTURE"; printf "%s\\n" "要約コマンドを実行しました。"; exit 0; fi',
        "exit 1",
      ].join("\n"),
    );
    chmodSync(codexPath, 0o755);

    Object.assign(process.env, {
      HOME: home,
      CODEX_HOME: codexHome,
      XDG_STATE_HOME: stateHome,
      CODEX_TEST_VERSION: "0.157.0",
      CODEX_TEST_PROMPT_CAPTURE: promptCapture,
    });
    globalThis.fetch = async () => ({ ok: true, text: async () => testChangelog });

    const event = { hook_event_name: "SessionStart", source: "startup" };
    assert.equal(await handleSessionStart(event), undefined);
    assert.equal(readFileSync(statePath, "utf8").trim(), "0.157.0");

    process.env.CODEX_TEST_VERSION = "0.157.1";
    const update = await handleSessionStart(event);
    assert.match(update.systemMessage, /0\.157\.0 から 0\.157\.1/);
    assert.match(update.systemMessage, /要約コマンドを実行しました/);
    assert.match(readFileSync(promptCapture, "utf8"), /既定モデルは gpt-6-sol/);
    assert.match(readFileSync(promptCapture, "utf8"), /端末の表示を改善しました/);
    assert.equal(readFileSync(statePath, "utf8").trim(), "0.157.1");

    assert.equal(await handleSessionStart(event), undefined);

    const noDetailsChangelog = `
      <main>
        <li data-codex-topics="codex-cli">
          <h3>Codex CLI 0.157.2</h3>
          <p>Release highlights could not be determined.</p>
        </li>
        <li data-codex-topics="codex-cli">
          <h3>Codex CLI 0.157.1</h3>
          <h4>Improvements</h4><ul><li>前回版の説明です。</li></ul>
        </li>
      </main>`;
    rmSync(promptCapture, { force: true });
    globalThis.fetch = async () => ({ ok: true, text: async () => noDetailsChangelog });
    process.env.CODEX_TEST_VERSION = "0.157.2";
    const noDetailsUpdate = await handleSessionStart(event);
    assert.match(noDetailsUpdate.systemMessage, /詳細がないため、使い方への影響は判断できませんでした/);
    assert.equal(existsSync(promptCapture), false);
    assert.equal(readFileSync(statePath, "utf8").trim(), "0.157.2");
  } finally {
    for (const [key, value] of previousEnvironment) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    globalThis.fetch = previousFetch;
    rmSync(testDirectory, { recursive: true, force: true });
  }
}

testReleaseRange();
testMissingPreviousRelease();
await testVersionStateFlow();
process.stdout.write("更新履歴の範囲・版状態・一度限りの案内: 成功\n");
