(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const nav = document.querySelector("[data-nav]");
  const toggle = document.querySelector("[data-nav-toggle]");
  const mobileMenu = document.querySelector("[data-mobile-menu]");

  // —— Sticky nav scroll state ——
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle("is-scrolled", window.scrollY > 8);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  // —— Mobile nav ——
  if (toggle && mobileMenu && nav) {
    const setOpen = (open) => {
      nav.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "关闭菜单" : "打开菜单");
      mobileMenu.hidden = !open;
    };

    toggle.addEventListener("click", () => {
      setOpen(toggle.getAttribute("aria-expanded") !== "true");
    });

    mobileMenu.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => setOpen(false));
    });

    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape") setOpen(false);
    });
  }

  // —— Active section highlighting ——
  const menuLinks = document.querySelectorAll(".site-nav__menu a[href^='#']");
  const sections = [...menuLinks]
    .map((a) => {
      const id = a.getAttribute("href")?.slice(1);
      return id ? document.getElementById(id) : null;
    })
    .filter(Boolean);

  if (menuLinks.length && sections.length && "IntersectionObserver" in window) {
    const sectionObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const id = entry.target.id;
          menuLinks.forEach((link) => {
            link.classList.toggle("is-active", link.getAttribute("href") === `#${id}`);
          });
        }
      },
      { rootMargin: "-35% 0px -55% 0px", threshold: 0 },
    );
    sections.forEach((el) => sectionObserver.observe(el));
  }

  // —— Scroll reveal ——
  const targets = document.querySelectorAll(".reveal");
  if (reduceMotion || !("IntersectionObserver" in window)) {
    targets.forEach((el) => el.classList.add("is-visible"));
  } else if (targets.length) {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        }
      },
      { rootMargin: "0px 0px -6% 0px", threshold: 0.1 },
    );
    targets.forEach((el) => observer.observe(el));
  }

  // —— Showcase tabs ——
  const tabs = document.querySelectorAll("[data-showcase]");
  const panels = document.querySelectorAll("[data-panel]");

  if (tabs.length && panels.length) {
    const activate = (key) => {
      tabs.forEach((tab) => {
        const active = tab.getAttribute("data-showcase") === key;
        tab.classList.toggle("is-active", active);
        tab.setAttribute("aria-selected", String(active));
      });
      panels.forEach((panel) => {
        const match = panel.getAttribute("data-panel") === key;
        panel.hidden = !match;
        panel.classList.toggle("is-active", match);
      });
    };

    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        const key = tab.getAttribute("data-showcase");
        if (key) activate(key);
      });
    });
  }

  // —— Version from public latest.json (best-effort) ——
  const versionPills = document.querySelectorAll("[data-version-pill]");
  const versionTexts = document.querySelectorAll("[data-version-text]");

  const applyVersion = (version, notes) => {
    if (!version) return;
    const label = notes ? `${notes} · v${version}` : `v${version}`;
    versionPills.forEach((el) => {
      el.textContent = label;
    });
    versionTexts.forEach((el) => {
      el.textContent = notes ? `当前 v${version} · ${notes}` : `当前 v${version}`;
    });
  };

  // GitHub raw may be blocked by CORS on Pages; try multiple sources silently.
  const versionSources = [
    "https://raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json",
    "https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json",
  ];

  const fetchVersion = async () => {
    for (const url of versionSources) {
      try {
        const res = await fetch(url, { cache: "no-cache" });
        if (!res.ok) continue;
        const data = await res.json();
        if (data?.latest) {
          applyVersion(String(data.latest), data.notes ? String(data.notes) : "");
          return;
        }
      } catch {
        // try next source
      }
    }
  };

  fetchVersion();
})();
