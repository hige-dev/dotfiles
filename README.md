# dotfiles

tmux・Codex・zsh を Ubuntu / Debian / WSL と macOS で再現する設定集です。セットアップと通知は Bash で動き、Python は不要です。通知データの JSON 読み取りには jq を使います。

## セットアップ

```bash
git clone git@github.com:hige-dev/dotfiles.git ~/work/tools/dotfiles
cd ~/work/tools/dotfiles
bash setup.sh --dry-run
bash setup.sh
exec zsh
codex login
```

SSH 鍵が未設定の環境では GitHub の HTTPS URL でも取得できます。Git が未導入の場合、Ubuntu では `sudo apt-get install git`、macOS では `xcode-select --install` で開発ツールを導入してから取得してください。

セットアップは OS を判定します。

| 環境 | 基本ツール | コピー用補助コマンド | 確認待ち通知 |
| --- | --- | --- | --- |
| Ubuntu / Debian | apt | wl-copy / xclip（導入済みの場合） | notify-send |
| WSL | apt | clip.exe | Windows PowerShell |
| macOS（Apple Silicon / Intel） | Homebrew | pbcopy | osascript |

macOS では Homebrew がなければ公式インストーラーを起動します。途中で権限確認や開発ツールの導入が必要になる場合があります。Ubuntu / Debian では apt 用の sudo 権限が必要です。いずれもネット接続が必要です。

Oh My Zsh・Powerlevel10k・入力候補・補完は `repositories.txt` の Git リビジョンで導入します。mise、Node.js、Codex、interview-dev-loop の版は `versions.sh` に固定しています。既存の zsh 拡張が別のリビジョンの場合は、勝手に切り替えず停止します。必要ならそのディレクトリを退避して再実行してください。

tmux と基本ツールは OS のパッケージを使い、版は固定しません。tmux の設定は 3.6 で検証しています。Linux のシステムクリップボードが必要なら、Wayland では wl-clipboard、X11 では xclip を別途導入してください。

tmux と Codex などのアプリからのコピーは、端末のクリップボード連携（OSC 52）を使います。tmux 自身のドラッグ選択はコピー後にコピーモードを終了します。Windows Terminal では `Ctrl+Shift+V` で現在のクリップボードを貼り付けられます。上表の補助コマンドは `scripts/tmux-copy.sh` で直接コピーする場合に使用します。

## 設定の配置と更新

依存関係を導入せず設定だけ配置する場合:

```bash
bash setup.sh --configs-only
```

設定はコピーで配置します。リポジトリ内のファイルを編集し、再実行して反映します。内容が違う既存ファイルやシンボリックリンクは、`~/.local/state/dotfiles/backups/<日時>/` に退避します。リンク先の内容は変更しません。同じ内容なら退避を増やしません。戻す場合は退避したファイルを元の配置先に戻してください。

新しい zsh を開くとシェル設定が反映されます。使用中の tmux は `tmux source-file ~/.tmux.conf` で再読み込みします。ログインシェルは変更しません。必要なら端末の設定を変更するか、利用する zsh のパスを確認して `chsh` を実行してください。

Powerlevel10k の現在の設定を保存しています。端末アプリのフォントには MesloLGS NF などの対応フォントを選択してください。端末アプリの背景色やフォント、Windows 側の設定はこのリポジトリに含みません。

## Codex と端末固有の設定

共通の設定は `codex/config.toml`、作業ルールは `codex/AGENTS.md` です。通常表示を使い、`Alt-r` または `/raw` でコピー向けの raw 表示へ切り替えられます。

端末固有のプロジェクト信頼設定などは、`codex/local.toml.example` を `codex/local.toml` にコピーして記述します。共通設定の後ろに追記して配置します。共通設定と同じキーやテーブルを重複定義しないでください。Bash では TOML の解析・検証や既存設定の自動取り込みは行いません。

**既存の Codex 設定は退避して置き換えます。** 引き継ぎたい信頼設定や追加プラグイン設定があれば、配置前に `codex/local.toml` に移してください。配置済みの `~/.codex/config.toml` に Codex が追記した設定も、次の配置で置き換わります。必要なものは退避ファイルから確認できます。

zsh の端末固有設定は `zsh/local.zsh` に記述すると `~/.zshrc.local` に配置します。これらのローカルファイルは Git の対象外です。tmux では操作中に端末の背景色、非アクティブに `#333333` を使います。

認証情報、履歴、セッション、キャッシュ、端末ごとの保存済み許可は収録しません。Codex へのログインとフックの信頼確認は移行先で行います。ChatGPT 側のリモートプラグインと接続サービスはアカウント側で設定してください。

通知を手動で確認する場合:

```bash
bash ~/.local/bin/agent-notify.sh --test
```

Windows / macOS の通知許可、WSL からの Windows コマンド実行、Linux のデスクトップ通知環境は端末側で設定してください。

Docker、Neovim 本体、プロジェクトごとの実行環境は対象外です。mise の有効化と既存の Neovim のパスは zsh に残しています。

## 検証と履歴

```bash
bash tests/check.sh
```

シェルの構文、一時ホームへの配置・再実行・退避、リンク先と認証情報の保護、通知の OS 分岐、macOS のコピー、tmux の起動と再読み込みを検証します。通知と macOS のコピーはコマンドを差し替えて確認し、実際のデスクトップには通知しません。

GitHub Actions でも Ubuntu / macOS 上で同じ検証を実行します。依存関係のフルインストールや、実際の端末のフォント・クリップボード・通知表示は別途確認してください。

以前のリポジトリの内容は、削除コミットの親で確認できます。

```bash
git log --oneline
git show 803f055:.zshrc
```

設定項目は [OpenAI の設定リファレンス](https://learn.chatgpt.com/docs/config-file/config-reference)、依存ツールは [mise の公式導入手順](https://mise.jdx.dev/installing-mise.html) と [Homebrew の公式導入手順](https://brew.sh/) を参照しています。
