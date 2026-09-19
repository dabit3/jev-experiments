// Reconstructed Devin UI fragments (dark theme). Pure HTML string builders.
(function () {
  const C = window.CONFIG;
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

  const appleGlyph =
    '<svg viewBox="0 0 24 24"><path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.9-.8-3.1-.8-1.6 0-3.1.9-3.9 2.4-1.7 2.9-.4 7.2 1.2 9.5.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.1.8 1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.7-1-2.7-4.1zM14.3 5.9c.6-.8 1.1-1.9.9-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.2-.6 2.9-1.4z"/></svg>';
  const sendGlyph = '<svg viewBox="0 0 24 24"><path d="M12 19V5M5 12l7-7 7 7"/></svg>';
  const monitorGlyph = '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg>';
  const listGlyph = '<svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h10"/></svg>';
  const diffGlyph = '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>';
  const branchGlyph = '<svg viewBox="0 0 24 24"><circle cx="6" cy="5" r="2.5"/><circle cx="6" cy="19" r="2.5"/><circle cx="18" cy="9" r="2.5"/><path d="M6 7.5v9M18 11.5c0 3-4 3-6 4"/></svg>';
  const sidebarGlyph = '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M9 4v16"/></svg>';
  const arrowL = '<svg viewBox="0 0 24 24"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>';
  const arrowR = '<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>';

  function macChip(dim) {
    return `<span class="chip${dim ? " dim" : ""}">${appleGlyph}macOS</span>`;
  }

  // Panel 1: the Devin composer with the environment selector.
  function composer(typed, showCaret) {
    return `
      <div class="composer-wrap">
        <div class="composer-brand">
          <img src="${C.media.lockup}" alt="Devin">
          <div class="seg"><span class="on">Agent</span><span>Ask</span></div>
        </div>
        <div class="composer">
          <div class="input">${typed ? esc(typed) : '<span class="placeholder">Ask Devin to build, fix or work on your code</span>'}${showCaret ? '<span class="caret"></span>' : ""}</div>
          <div class="row">
            <div class="left"><span class="plus">+</span><span>Fusion</span>${macChip(false)}</div>
            <div class="right"><div class="send">${sendGlyph}</div></div>
          </div>
        </div>
      </div>`;
  }

  // Panel 2: Swift editor. Source is the real NativeViewport.swift from voxelhearth.
  const CODE_LINES = [
    '<span class="k">import</span> <span class="t">AppKit</span>',
    '<span class="k">import</span> <span class="t">MetalKit</span>',
    "",
    '<span class="k">final class</span> <span class="t">NativeViewport</span>: <span class="t">MTKView</span> {',
    '  <span class="k">var</span> game: <span class="t">Game</span>?',
    '  <span class="k">private var</span> captured = <span class="k">false</span>',
    "",
    '  <span class="k">override func</span> <span class="f">mouseDown</span>(with event: <span class="t">NSEvent</span>) {',
    '    <span class="k">guard let</span> game, !game.blocked <span class="k">else</span> { <span class="k">return</span> }',
    '    window?.<span class="f">makeFirstResponder</span>(<span class="k">self</span>)',
    '    <span class="k">if</span> !captured {',
    '      captured = <span class="k">true</span>',
    '      <span class="t">NSCursor</span>.<span class="f">hide</span>()',
    '      <span class="f">CGAssociateMouseAndMouseCursorPosition</span>(<span class="s">0</span>)',
    '    } <span class="k">else</span> {',
    '      game.<span class="f">startBreak</span>()',
    "    }",
    "  }",
  ];
  const plain = (html) => html.replace(/<[^>]+>/g, "");
  const CODE_TOTAL = CODE_LINES.reduce((n, l) => n + plain(l).length + 1, 0);

  // Reveal `count` characters of highlighted code without breaking tags.
  function revealHtml(html, count) {
    let out = "", shown = 0, i = 0;
    while (i < html.length && shown < count) {
      if (html[i] === "<") {
        const j = html.indexOf(">", i);
        out += html.slice(i, j + 1);
        i = j + 1;
      } else if (html[i] === "&") {
        const j = html.indexOf(";", i);
        out += html.slice(i, j + 1);
        i = j + 1;
        shown++;
      } else {
        out += html[i++];
        shown++;
      }
    }
    // close any open spans
    const opens = (out.match(/<span/g) || []).length, closes = (out.match(/<\/span>/g) || []).length;
    for (let k = closes; k < opens; k++) out += "</span>";
    return out;
  }

  function editor(progress) {
    let budget = Math.floor(progress * CODE_TOTAL);
    const lines = [];
    for (let i = 0; i < CODE_LINES.length; i++) {
      const len = plain(CODE_LINES[i]).length;
      if (budget <= 0) break;
      const n = Math.min(len, budget);
      const partial = n < len || budget === n;
      lines.push(`<span class="ln">${i + 1}</span>${revealHtml(CODE_LINES[i], n)}${partial && progress < 1 ? '<span class="caret"></span>' : ""}`);
      budget -= len + 1;
    }
    return `
      <div class="editor">
        <div class="tabs">
          <div class="tab on">${branchGlyph}NativeViewport.swift</div>
          <div class="tab">Game.swift</div>
          <div class="tab">HearthApp.swift</div>
          <div class="crumb">voxelhearth / apple / Sources</div>
        </div>
        <pre>${lines.join("\n")}</pre>
      </div>`;
  }

  // Panels 3, 4, 6: the Devin session view with chat on the left and Computer on the right.
  const simscene = (imgId) => `<div class="simscene">
           <div class="simtitle"><div class="lights"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></div><div class="name">iPhone 17<small>iOS 26.5</small></div></div>
           <div class="phone"><div class="glass"><img id="${imgId}" alt=""></div></div>
         </div>`;

  // mode: "mac", "iphone" or "both" (Mac desktop and Simulator side by side).
  // Footage images get ids so storyboard.js can swap frames; for "both" the ids are `${imgId}Mac` and `${imgId}Phone`.
  function session(mode, imgId, done) {
    const screen = mode === "mac"
      ? `<img class="mac" id="${imgId}" alt="">`
      : mode === "iphone"
        ? simscene(imgId)
        : `<div class="split"><div class="half"><img class="mac" id="${imgId}Mac" alt=""></div><div class="half">${simscene(imgId + "Phone")}</div></div>`;
    const reply = done ? C.text.devinDone : C.text.devinReply;
    const status = done
      ? `<div class="status"><span class="dot" style="background:${C.colors.green}"></span>Devin is awaiting instructions</div>`
      : `<div class="status"><span class="dot"></span>Devin is playing VoxelHearth ${mode === "mac" ? "on the Mac desktop" : "in the iPhone Simulator"}</div>`;
    return `
      <div class="session">
        <div class="chat">
          <div class="topbar">${sidebarGlyph.replace("<svg", '<svg class="icon"')}<span class="title">${esc(C.text.sessionTitle)}</span>${macChip(false)}</div>
          <div class="messages">
            <div class="user">${esc(C.text.prompt)}</div>
            <div class="devin"><img src="${C.media.avatar}" alt=""><p>${esc(reply)}</p></div>
            ${status}
          </div>
          <div class="composer">
            <div class="input"><span class="placeholder">Ask Devin to build features, fix bugs, or work on your code</span></div>
            <div class="row">
              <div class="left"><span class="plus">+</span><span>Fusion</span>${macChip(true)}</div>
              <div class="right"><div class="send">${sendGlyph}</div></div>
            </div>
          </div>
        </div>
        <div class="computer">
          <div class="tabs">
            <div class="tab">${listGlyph}Progress</div>
            <div class="tab">${diffGlyph}Changes</div>
            <div class="tab on">${monitorGlyph}Computer</div>
            <div class="tab">${branchGlyph}PR</div>
            <div class="spacer"></div>
          </div>
          <div class="body">
            <div class="screen">${screen}</div>
            <div class="controls">${arrowL}${arrowR}<div class="live"><i></i>Live</div><div class="bar"><i></i></div><span>Auto</span></div>
          </div>
        </div>
      </div>`;
  }

  window.UI = { composer, editor, session, CODE_TOTAL };
})();
