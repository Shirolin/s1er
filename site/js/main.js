(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const status = document.querySelector("[data-compose-status]");
  const say = (msg) => {
    if (status) status.textContent = msg;
  };

  // —— 首屏帖子：引用进回复框 ——
  const quoteBtns = [...document.querySelectorAll("[data-quote-btn]")];
  const composeLine = document.querySelector("[data-compose-line]");

  if (quoteBtns.length && composeLine) {
    const hint = composeLine.innerHTML;

    const reset = () => {
      composeLine.innerHTML = hint;
      quoteBtns.forEach((b) => b.setAttribute("aria-pressed", "false"));
    };

    quoteBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const { quoteFloor, quoteAuthor, quoteText } = btn.dataset;
        quoteBtns.forEach((b) => b.setAttribute("aria-pressed", String(b === btn)));

        const label = document.createElement("b");
        label.textContent = `引用 ${quoteFloor} · ${quoteAuthor}`;
        const text = document.createElement("span");
        text.textContent = quoteText;
        const cancel = document.createElement("button");
        cancel.type = "button";
        cancel.className = "thread__cancel";
        cancel.textContent = "取消";
        cancel.addEventListener("click", () => {
          reset();
          say(`已取消引用 ${quoteFloor}`);
        });

        composeLine.replaceChildren(label, text, cancel);
        say(`已引用 ${quoteFloor}，回复框带上了出处`);
      });
    });
  }

  // —— 楼层：菜单与引用 ——
  const more = document.querySelector("[data-floor-more]");
  const menu = document.querySelector("[data-floor-menu]");

  if (more && menu) {
    more.addEventListener("click", () => {
      const open = more.getAttribute("aria-expanded") !== "true";
      more.setAttribute("aria-expanded", String(open));
      more.classList.toggle("is-on", open);
      menu.hidden = !open;
    });
  }

  const quoteBtn = document.querySelector("[data-floor-quote]");
  const quoted = document.querySelector("[data-quote]");
  const quoteWord = document.querySelector("[data-quote-word]");

  if (quoteBtn && quoted) {
    const floor = quoted.closest(".floor");
    quoteBtn.addEventListener("click", () => {
      const off = floor.classList.toggle("is-unquoted");
      if (quoteWord) quoteWord.textContent = off ? "未引用" : "已引用";
    });
  }

  // —— 种子色 ——
  const seeds = [...document.querySelectorAll(".seed")];
  seeds.forEach((seed) => {
    seed.addEventListener("click", () => {
      seeds.forEach((s) => {
        const on = s === seed;
        s.classList.toggle("is-on", on);
        s.setAttribute("aria-pressed", String(on));
      });
    });
  });

  // —— 段落入场 ——
  const parts = [];
  document.querySelectorAll(".section").forEach((section) => {
    const items = section.querySelectorAll(":scope > .wrap > *");
    items.forEach((el, i) => {
      el.classList.add("part");
      el.style.setProperty("--d", `${i * 80}ms`);
      parts.push(el);
    });
  });

  if (reduceMotion || !("IntersectionObserver" in window)) {
    parts.forEach((el) => el.classList.add("is-in"));
  } else {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.05 },
    );
    parts.forEach((el) => observer.observe(el));
  }

  // —— 版本（尽力而为，失败不打扰）——
  const versionTexts = document.querySelectorAll("[data-version-text]");
  if (!versionTexts.length) return;

  const sources = [
    "https://raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json",
    "https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json",
  ];

  const apply = (version, notes) => {
    versionTexts.forEach((el) => {
      const line = notes.replace(/^Beta\s*[—–-]\s*[\d.]+\s*[：:]\s*/, "").trim();
      el.textContent = line ? `当前 v${version} · ${line}` : `当前 v${version}`;
    });
  };

  const fetchVersion = async () => {
    for (const url of sources) {
      try {
        const res = await fetch(url, { cache: "no-cache" });
        if (!res.ok) continue;
        const data = await res.json();
        if (data && data.latest) {
          apply(String(data.latest), data.notes ? String(data.notes) : "");
          return true;
        }
      } catch {
        // 换下一个源
      }
    }
    return false;
  };

  fetchVersion().then((ok) => {
    if (ok) return;
    versionTexts.forEach((el) => {
      el.textContent = "版本与更新说明见 GitHub Releases";
    });
  });
})();
