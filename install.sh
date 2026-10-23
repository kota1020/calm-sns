#!/bin/zsh
# Calm を自分のiPhoneに入れる（1コマンド）。必要な物：Mac・Xcode（Apple IDでサインイン済み）・有料のApple開発者登録・ケーブルでつないだiPhone
#   ./install.sh            … チームIDは自動で探す
#   CALM_TEAM=XXXXXXXXXX ./install.sh   … チームIDを指定
set -e
cd "$(dirname "$0")"
say() { print -P "%F{green}▶%f $1"; }
fail() { print -P "%F{red}✗%f $1"; exit 1; }

# 1) 道具
xcode-select -p >/dev/null 2>&1 || fail "Xcode が入っていません。App Store から Xcode を入れて、一度開いてください"
if ! command -v xcodegen >/dev/null; then
  command -v brew >/dev/null || fail "Homebrew が要ります：https://brew.sh の1行を実行してから、もう一度"
  say "xcodegen を入れます"; brew install xcodegen
fi

# 2) チームID（Xcodeにサインインした開発者のID）
if [[ -z "$CALM_TEAM" ]]; then
  CALM_TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | grep -o 'OU *= *[A-Z0-9]\{10\}' | head -1 | grep -o '[A-Z0-9]\{10\}$')
fi
[[ -n "$CALM_TEAM" ]] || fail "チームIDが見つかりません。Xcode → Settings → Accounts でApple IDを足し、Manage Certificates で Apple Development を作ってから、もう一度"
say "チームID: $CALM_TEAM"

# 3) アプリの名前（人ごとに変える。同じ名前は世界で1つしか使えない）
export CALM_TEAM
export CALM_PREFIX=${CALM_PREFIX:-com.calm$(echo "$CALM_TEAM" | tr 'A-Z' 'a-z')}
say "アプリのID: $CALM_PREFIX.calm"

# 3.5) インスタとTikTokのアイコン（各社の物なのでリポには入れず、App Storeの公開画像を取ってくる）
for pair in "ig 389801252" "tt 1235601864"; do
  set -- ${=pair}
  f="Resources/icon_$1.png"
  [[ -s "$f" ]] && continue
  u=$(curl -s "https://itunes.apple.com/lookup?id=$2&country=jp" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["results"][0]["artworkUrl512"])' 2>/dev/null)
  [[ -n "$u" ]] && curl -s -o "$f" "${u/512x512bb.jpg/1024x1024bb.png}" && say "アイコンを取ってきた: $f"
done

# 4) つないだiPhone
DEV=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /connected|available/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{36}$/) {print $i; exit}}')
[[ -n "$DEV" ]] || fail "iPhoneが見つかりません。ケーブルでつなぎ、ロックを解除して「このコンピュータを信頼」を押してください"
UDID=$(xcrun devicectl device info details --device "$DEV" 2>/dev/null | awk '/ udid:/ {print $NF; exit}')
[[ -n "$UDID" ]] || fail "iPhoneの番号が読めません。ロックを解除して、もう一度"
say "iPhone: $DEV"

# 5) 作って入れる
say "作っています（初回は3〜5分）"
rm -rf build/Build/Products/Debug-iphoneos/Calm.app   # 前に作った物で「入った」と誤って出さないように
xcodegen generate >/dev/null
# Xcodeにサインインしていない時は、App Store Connect の鍵でもよい（ASC_KEY_PATH・ASC_KEY_ID・ASC_ISSUER）
AUTH=()
[[ -n "$ASC_KEY_PATH" ]] && AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER")
xcodebuild -project Calm.xcodeproj -scheme Calm -destination "id=$UDID" -derivedDataPath build \
  -allowProvisioningUpdates "${AUTH[@]}" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u
[[ -d build/Build/Products/Debug-iphoneos/Calm.app ]] || fail "作れませんでした（上の error: を見てください）"
say "iPhoneに入れています"
xcrun devicectl device install app --device "$DEV" build/Build/Products/Debug-iphoneos/Calm.app | grep -i "installed" || fail "入れられませんでした"

print -P "\n%F{green}✓ 入りました%f
最初の1回だけ iPhone で：
  1. 設定 → プライバシーとセキュリティ → デベロッパモード をオン（出ていれば）
  2. 設定 → 一般 → VPNとデバイス管理 → 自分のApple ID →「信頼」
  3. Calm を開き、止める →「許可する」（スクリーンタイム）
  4. インスタ・TikTok を開いてログイン"
