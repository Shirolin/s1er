(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const root = document.documentElement;

  // —— 明暗主题 ——
  const themeBtn = document.querySelector("[data-theme-toggle]");
  const themeMeta = document.querySelector('meta[name="theme-color"]');

  const applyTheme = (theme) => {
    root.dataset.theme = theme;
    const light = theme === "light";
    if (themeBtn) {
      themeBtn.setAttribute("aria-pressed", String(light));
      themeBtn.setAttribute("aria-label", light ? "切换到深色主题" : "切换到浅色主题");
    }
    if (themeMeta) themeMeta.setAttribute("content", light ? "#f5f5f8" : "#09090b");
  };

  applyTheme(root.dataset.theme === "light" ? "light" : "dark");

  if (themeBtn) {
    themeBtn.addEventListener("click", () => {
      const next = root.dataset.theme === "light" ? "dark" : "light";
      applyTheme(next);
      try {
        localStorage.setItem("s1er-theme", next);
      } catch {
        // 隐私模式下存不了，本次切换照常生效
      }
    });
  }

  // —— 首屏帖子：引用进回复框 ——
  const heroBtns = [...document.querySelectorAll("[data-hero-quote]")];
  const heroLine = document.querySelector("[data-compose-line]");

  const buildQuote = (dataset, onCancel) => {
    const label = document.createElement("b");
    label.textContent = `引用 ${dataset.quoteFloor} · ${dataset.quoteAuthor}`;
    const text = document.createElement("span");
    text.textContent = dataset.quoteText;
    const cancel = document.createElement("button");
    cancel.type = "button";
    cancel.className = "app__cancel";
    cancel.textContent = "取消";
    cancel.addEventListener("click", onCancel);
    return [label, text, cancel];
  };

  if (heroBtns.length && heroLine) {
    const hint = heroLine.innerHTML;
    const status = document.querySelector("[data-compose-status]");
    const say = (msg) => {
      if (status) status.textContent = msg;
    };

    const reset = () => {
      heroLine.innerHTML = hint;
      heroBtns.forEach((b) => b.setAttribute("aria-pressed", "false"));
    };

    heroBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        heroBtns.forEach((b) => b.setAttribute("aria-pressed", String(b === btn)));
        heroLine.replaceChildren(
          ...buildQuote(btn.dataset, () => {
            reset();
            say(`已取消引用 ${btn.dataset.quoteFloor}`);
          }),
        );
        say(`已引用 ${btn.dataset.quoteFloor}，回复框带上了出处`);
      });
    });
  }

  // —— 一层楼：菜单与引用 ——
  const floorMore = document.querySelector("[data-floor-more]");
  const floorMenu = document.querySelector("[data-floor-menu]");
  const floorLine = document.querySelector("[data-floor-compose]");
  const floorWord = document.querySelector("[data-quote-word]");
  const floorBtns = [...document.querySelectorAll("[data-quote-btn], [data-floor-quote]")];

  if (floorMore && floorMenu) {
    floorMore.addEventListener("click", (event) => {
      event.stopPropagation();
      const open = floorMore.getAttribute("aria-expanded") !== "true";
      floorMore.setAttribute("aria-expanded", String(open));
      floorMenu.hidden = !open;
    });
  }

  if (floorLine && floorBtns.length) {
    const hint = floorLine.innerHTML;

    const reset = () => {
      floorLine.innerHTML = hint;
      floorBtns.forEach((b) => b.setAttribute("aria-pressed", "false"));
      if (floorWord) floorWord.textContent = "回帖";
    };

    floorBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        floorBtns.forEach((b) => b.setAttribute("aria-pressed", String(b === btn)));
        floorLine.replaceChildren(...buildQuote(btn.dataset, reset));
        if (floorWord) floorWord.textContent = "已引用";
        if (floorMenu) {
          floorMenu.hidden = true;
          floorMore?.setAttribute("aria-expanded", "false");
        }
      });
    });
  }

  // —— 种子色与字号：整个页面跟着换 ——
  const seedBtns = [...document.querySelectorAll(".seed")];
  const sizeBtns = [...document.querySelectorAll(".sizes button")];

  const applySeed = (seed) => {
    root.dataset.seed = seed;
    seedBtns.forEach((b) => {
      const on = b.dataset.seed === seed;
      b.classList.toggle("is-on", on);
      b.setAttribute("aria-pressed", String(on));
    });
  };

  const applySize = (size) => {
    root.dataset.size = size;
    sizeBtns.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.size === size)));
  };

  const remember = (key, value) => {
    try {
      localStorage.setItem(key, value);
    } catch {
      // 隐私模式下存不了，本次切换照常生效
    }
  };

  if (seedBtns.length) {
    applySeed(root.dataset.seed || "blue");
    seedBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        applySeed(btn.dataset.seed);
        remember("s1er-seed", btn.dataset.seed);
      });
    });
  }

  if (sizeBtns.length) {
    applySize(root.dataset.size || "normal");
    sizeBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        applySize(btn.dataset.size);
        remember("s1er-size", btn.dataset.size);
      });
    });
  }

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
