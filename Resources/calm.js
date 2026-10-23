// Calm：インスタとTikTokのウェブ版から、リール・おすすめ・広告を消してフォロー中だけにする。
// 設定は Calm が先に入れる window.__calmCfg（search=検索を止める / ads=広告を消す / suggested=おすすめの投稿を消す / live=ライブを止める）。
// 消した数は Calm に送り、上の帯に「広告0・おすすめ0」と出す。
(function () {
  "use strict";
  if (window.__calm) return;
  window.__calm = true;
  const IG = /(^|\.)instagram\.com$/.test(location.hostname);
  const TT = /(^|\.)tiktok\.com$/.test(location.hostname);
  if (!IG && !TT) return;
  const desktopTT = TT && /Macintosh/.test(navigator.userAgent);
  // 動画が勝手にiPhoneの全画面プレーヤーになるのを止める：サイトが呼ぶ全画面の命令を無効にし、必ず画面の中で再生させる
  try {
    const P = HTMLVideoElement.prototype;
    P.webkitEnterFullscreen = P.webkitEnterFullScreen = function () {};
    Element.prototype.requestFullscreen = Element.prototype.webkitRequestFullscreen = function () { return Promise.resolve(); };
    const inl = (v) => { v.setAttribute("playsinline", ""); v.setAttribute("webkit-playsinline", ""); v.playsInline = true; };
    const op = P.play; P.play = function () { inl(this); return op.apply(this, arguments); };
  } catch (_) {}
  const cfg = Object.assign({ search: true, ads: true, suggested: true, live: true }, window.__calmCfg || {});

  // 1) 行ってはいけない場所 → フォロー中へ戻す
  // ホームは本物と同じ「/」（上にストーリーの列が出る）。おすすめの投稿と広告は 3) で消す
  const IG_HOME = "/";
  function igBlocked(p, q) {
    if (/^\/reels(\/|$)/.test(p)) return true;                                   // リールの一覧・めくる画面。/reel/ID の1本は通す
    if (/^\/explore\/search(\/|$)/.test(p)) return cfg.search;                    // 人の検索
    if (/^\/explore(\/|$)/.test(p)) return true;                                  // 発見（おすすめの並び）
    return false;
  }
  function ttBlocked(p) {
    if (p === "/" || /^\/(foryou|explore|friends|drama|shortdrama|short-drama)(\/|$)/.test(p)) return true;
    if (cfg.search && /^\/search(\/|$)/.test(p)) return true;
    if (cfg.live && /^\/live(\/|$)/.test(p)) return true;
    return false;
  }
  // リール1本から上下にめくって次のリールへ進んだら、元の1本に戻す
  let lastReel = (/^\/reel\/[^/]+/.exec(location.pathname) || [null])[0];
  function guard() {
    const p = location.pathname, q = location.search;
    if (IG) {
      const m = (/^\/reel\/[^/]+/.exec(p) || [null])[0];
      if (m && lastReel && m !== lastReel) { history.back(); return; }
      lastReel = m;
      if (igBlocked(p, q)) location.replace(IG_HOME + location.hash);
    } else if (TT && ttBlocked(p)) location.replace("/following");
  }
  guard();
  for (const k of ["pushState", "replaceState"]) {
    const orig = history[k];
    history[k] = function () { const r = orig.apply(this, arguments); setTimeout(guard, 0); return r; };
  }
  addEventListener("popstate", guard);

  // 2) ボタンを消す（読み込み前から効くようにCSSで）
  // フォロー中の画面にはストーリーの列が出ないので、ホームを開いてストーリーの列だけ残し、投稿（おすすめ混じり）は隠す
  const storiesOnly = IG && location.pathname === "/" && /calm=stories/.test(location.search);
  const css = IG ? `
    ${storiesOnly ? 'main article, main [role="feed"], main div:has(> article), main [role="progressbar"], main svg[aria-label="Loading..."], main [data-visualcompletion="loading-state"] { display: none !important; }' : ""}
    a[href="/reels/"], a[href^="/reels"], a[href*="/reels/audio"] { display: none !important; }
    ${cfg.search ? 'a[href="/explore/"], a[href^="/explore"] { display: none !important; }' : ""}
  ` : `
    a[href="/foryou"], a[href^="/foryou"], a[href="/explore"], a[href^="/explore"], a[href^="/friends"],
    [data-e2e="nav-foryou"], [data-e2e="nav-explore"], [data-e2e="nav-friends"],
    ${cfg.search ? '[data-e2e="search-box"], a[href^="/search"], [data-e2e="nav-search"],' : ""}
    ${cfg.live ? 'a[href^="/live"], [data-e2e="nav-live"],' : ""}
    [class*="DivOpenInAppContainer"], [class*="BannerContainer"],
    footer, [class*="--DivRecommendListContainer"],
    [data-e2e*="story"], [data-e2e*="Story"], [class*="DivStory"], [class*="StoryRing"], [class*="StoriesContainer"], a[href*="/story/"] { display: none !important; }
  `;
  // TikTokの自分のページはパソコン版なので、携帯の幅に収まるように少し縮める（いいね・保存のタブが右に隠れないように）
  // 左の縦のメニュー（おすすめ・ショートドラマ等へ行く）は消し、空いた分だけ本文を広げる
  // 縮めるのは自分のページだけ（フォロー中の動画は縮めると小さくなる）
  const zoomCss = desktopTT ? `
    ${/^\/(@|profile)/.test(location.pathname) && !/\/video\//.test(location.pathname) ? "html { zoom: 0.8 !important; }" : ""}
    [role="tablist"] { overflow-x: auto !important; flex-wrap: nowrap !important; }
  ` : "";
  // 左の縦のメニュー（おすすめ・ショートドラマ等へ行く）を消す。名前で探すと外枠ごと消えて真っ白になるので、
  // メニューのリンクから上にたどり、幅が細い（150px以下）一番外の箱だけを消す
  let navDone = false;
  function hideSideNav(root) {
    if (!desktopTT || navDone) return;
    root.querySelectorAll('a[aria-label*="For You"], a[href="/"], a[href^="/explore"], a[href*="drama"], a[href^="/live"]').forEach((a) => {
      let box = null;
      for (let e = a; e && e !== document.body; e = e.parentElement) {
        const w = e.getBoundingClientRect().width;
        if (w > 0 && w <= 150) box = e; else if (w > 150) break;
      }
      if (box) { hide(box); navDone = true; dispatchEvent(new Event("calm-nav-hidden")); }
    });
  }
  function addStyle() {
    if (document.getElementById("calm-style")) return;
    const style = document.createElement("style");
    style.id = "calm-style";
    style.textContent = css + zoomCss;
    const root = document.head || document.documentElement;
    if (root) root.appendChild(style);
  }
  addStyle();
  addEventListener("DOMContentLoaded", addStyle);

  // 3) 広告・おすすめの投稿・「アプリで開く」を消す
  const counts = { ads: 0, suggested: 0 };
  let sent = "";
  function report() {
    const s = JSON.stringify(counts);
    if (s === sent) return;
    sent = s;
    try { window.webkit.messageHandlers.calm.postMessage(counts); } catch (_) {}
  }
  function hide(el, kind) {
    if (!el || el.dataset.calmHidden) return;
    el.dataset.calmHidden = "1";
    el.style.setProperty("display", "none", "important");
    if (kind) counts[kind] += 1;
  }
  const AD_WORDS = /^(Sponsored|広告)$/;
  const SUGGEST_WORDS = /^(Suggested for you|Suggested posts|おすすめ|おすすめの投稿|あなたへのおすすめ|Suggested Reels)$/;
  const APP_WORDS = /^(Open app|Open TikTok|Open Instagram|Use the app|Get the app|アプリで開く|アプリを開く|Instagramを開く|アプリを入手)$/;
  // 軽くするため、毎回ページ全体は見ない。新しく足された部分だけを0.25秒ごとにまとめて見る
  function cleanIn(root) {
    if (!root.querySelectorAll) return;
    hideSideNav(root);
    if (TT) {
      root.querySelectorAll('footer, [class*="--DivRecommendListContainer"]').forEach((e) => hide(e));
;
    }
    if (IG) {
      if (cfg.ads || cfg.suggested) {
        root.querySelectorAll("article span, span").forEach((el) => {
          if (el.childElementCount > 1) return;
          const t = el.textContent;
          if (!t || t.length > 30) return;
          const s = t.trim();
          if (cfg.ads && AD_WORDS.test(s)) hide(el.closest("article"), "ads");
          else if (cfg.suggested && SUGGEST_WORDS.test(s)) {
            const box = el.closest("article") || (el.parentElement && el.parentElement.parentElement);
            if (box && box !== document.body && box.tagName !== "MAIN") hide(box, "suggested");
          }
        });
      }
    }
    // 「アプリの方が便利」の案内は「今はしない」を押して閉じる。「アプリで開く」は消す
    root.querySelectorAll("button, div[role=button], a").forEach((el) => {
      if (el.childElementCount > 3) return;
      const t = el.textContent;
      if (!t || t.length > 30) return;
      const s = t.trim();
      if (/^(Not now|今はしない|後で|Not Now)$/.test(s) && !el.dataset.calmClicked) { el.dataset.calmClicked = "1"; el.click(); }
      else if (APP_WORDS.test(s)) hide(el);
    });
  }
  const queue = new Set();
  let timer = 0;
  function flush() {
    timer = 0;
    addStyle();   // サイトが<head>を作り直すと消えるので毎回確かめる
    for (const n of queue) if (n.isConnected) cleanIn(n);
    queue.clear();
    report();
  }
  function clean() { queue.add(document.documentElement); if (!timer) timer = setTimeout(flush, 0); }
  window.__calmClean = clean;
  // TikTokの携帯版には「保存」ボタンが無いので足す。押すと、Calmが裏のパソコン版でその動画の保存ボタンを押す
  if (TT && !desktopTT) {
    const fiberId = (el) => {
      const k = Object.keys(el).find((x) => x.startsWith("__reactFiber"));
      for (let f = k && el[k], n = 0; f && n < 12; f = f.return, n++) {
        const id = f.memoizedProps && f.memoizedProps.id;
        if (typeof id === "string" && /^\d{17,20}$/.test(id)) return id;
      }
      return null;
    };
    const ICON = '<svg viewBox="0 0 24 24" width="30" height="30"><path fill="currentColor" d="M6 2.8h12a1.2 1.2 0 0 1 1.2 1.2v17.1a.6.6 0 0 1-.95.49L12 17.3l-6.25 4.29A.6.6 0 0 1 4.8 21.1V4A1.2 1.2 0 0 1 6 2.8z"/></svg>';
    const saved = new Set(JSON.parse(sessionStorage.getItem("calmSaved") || "[]"));
    function paint(btn, state) {
      btn.dataset.state = state;
      btn.style.color = state === "on" ? "#FACE15" : "#fff";
      btn.querySelector("span").textContent = state === "busy" ? "…" : state === "on" ? "保存済み" : state === "fail" ? "もう一度" : "保存";
    }
    window.__calmSaved = (id, ok) => {
      if (ok) { saved.add(id); sessionStorage.setItem("calmSaved", JSON.stringify([...saved])); }
      document.querySelectorAll('.calm-save[data-id="' + id + '"]').forEach((b) => paint(b, ok ? "on" : "fail"));
    };
    function addSave() {
      document.querySelectorAll('[data-e2e="video-share-count"]').forEach((cnt) => {
        const slide = cnt.closest('[data-e2e^="video-slide"], [data-e2e="video-card"]');
        if (!slide || slide.querySelector(".calm-save")) return;
        const id = fiberId(slide);
        if (!id) return;
        const user = (slide.querySelector('[data-e2e="video-username"]') || {}).textContent || "";
        const btn = document.createElement("div");
        btn.className = "calm-save"; btn.dataset.id = id;
        btn.style.cssText = "display:flex;flex-direction:column;align-items:center;margin-top:14px;font:600 12px -apple-system;text-shadow:0 1px 2px rgba(0,0,0,.5);cursor:pointer";
        btn.innerHTML = ICON + "<span></span>";
        paint(btn, saved.has(id) ? "on" : "off");
        btn.addEventListener("click", (ev) => {
          ev.preventDefault(); ev.stopPropagation();
          if (btn.dataset.state === "busy" || btn.dataset.state === "on") return;
          paint(btn, "busy");
          try { window.webkit.messageHandlers.calm.postMessage({ save: { id, user: user.trim().replace(/^@/, "") } }); } catch (_) { paint(btn, "fail"); }
        }, true);
        // ボタン列の中に入れると列の高さが崩れて共有ボタンが隠れるので、動画の上に重ねて共有の下に置く
        btn.style.position = "absolute"; btn.style.zIndex = "3"; btn.style.width = "60px";
        if (getComputedStyle(slide).position === "static") slide.style.position = "relative";
        slide.appendChild(btn);
      });
      // 右のボタン列（いいね〜共有）を少し上げて、下の音楽の丸との間に保存の場所を空ける
      document.querySelectorAll('[data-e2e="video-share-count"]').forEach((cnt) => {
        let col = cnt.parentElement;
        while (col && !col.querySelector('[data-e2e="video-like-button"]')) col = col.parentElement;
        if (col && !col.dataset.calmUp) { col.dataset.calmUp = "1"; col.style.setProperty("transform", "translateY(-80px)", "important"); }
      });
      // 位置合わせ：共有の数字のすぐ下
      document.querySelectorAll(".calm-save").forEach((btn) => {
        const slide = btn.parentElement, cnt = slide.querySelector('[data-e2e="video-share-count"]');
        if (!cnt) return;
        const a = cnt.getBoundingClientRect(), b = slide.getBoundingClientRect();
        btn.style.left = (a.left + a.width / 2 - b.left - 30) + "px";
        btn.style.top = (a.bottom - b.top + 6) + "px";
      });
    }
    setInterval(addSave, 700);
  }
  // TikTokの上のストーリーの列を消す：一つ目の動画より上にある、丸い顔写真が2つ以上並んだ箱。名前では探せない（毎回変わる）ので形で探す。
  // 軽くするため、ページ全体は探さない。一つ目の動画の親をたどり、その「前にある兄弟」だけを見る。消せたらやめる
  let storiesDone = false, storyTries = 0;
  function hideTTStories() {
    if (storiesDone || ++storyTries > 40) { clearInterval(storyTimer); return; }
    const v = document.querySelector("video");
    if (!v) return;
    const top = v.getBoundingClientRect().top;
    for (let a = v; a && a !== document.body; a = a.parentElement) {
      for (let p = a.previousElementSibling; p; p = p.previousElementSibling) {
        if (p.dataset.calmHidden || p.querySelector("video, nav, header")) continue;
        const r = p.getBoundingClientRect();
        if (r.height > 20 && r.bottom <= top + 4) { if (p.querySelectorAll("img").length >= 2) storiesDone = true; hide(p); }
      }
      const cs = getComputedStyle(a);
      if (parseFloat(cs.paddingTop) > 80) a.style.setProperty("padding-top", "8px", "important");
      if (parseFloat(cs.marginTop) > 80) a.style.setProperty("margin-top", "8px", "important");
    }
  }
  const storyTimer = TT ? setInterval(hideTTStories, 500) : 0;

  const mo = new MutationObserver((list) => {
    for (const m of list) for (const n of m.addedNodes) if (n.nodeType === 1) queue.add(n.parentElement || n);
    if (queue.size && !timer) timer = setTimeout(flush, 250);
  });
  // 読み込みのごく最初は<html>がまだ無いことがあるので、できてから見張る
  (function watch() { if (document.documentElement) mo.observe(document.documentElement, { childList: true, subtree: true }); else setTimeout(watch, 10); })();
  addEventListener("DOMContentLoaded", clean);
  addEventListener("load", clean);

  // 4) 動画の先読み：画面の下1枚分に入った動画だけ先に読み込む（2枚分だと重くなる）
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      const v = e.target;
      if (v.preload !== "auto") v.preload = "auto";
      if (v.readyState === 0 && (v.currentSrc || v.src || v.querySelector("source"))) { try { v.load(); } catch (_) {} }
      io.unobserve(v);
    }
  }, { rootMargin: "0px 0px 100% 0px" });
  const seen = new WeakSet();
  function scan() {
    document.querySelectorAll("video").forEach((v) => {
      if (seen.has(v)) return;
      seen.add(v);
      io.observe(v);
    });
  }
  let scanT = 0;
  const mo2 = new MutationObserver(() => { if (!scanT) scanT = setTimeout(() => { scanT = 0; scan(); }, 300); });
  (function watch() { if (document.documentElement) mo2.observe(document.documentElement, { childList: true, subtree: true }); else setTimeout(watch, 10); })();
})();
