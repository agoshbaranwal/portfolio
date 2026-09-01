/* pen.js: the only script on the site, and the site never needs it.
   Everything here is delight on top of pages that are complete without JS:
   1. the theme choice follows you across pages and never flashes,
   2. the highlighter draws itself on when you reach the thing it marks,
      and blocks rise into place as they arrive.
   Both respect prefers-reduced-motion. No frameworks, no tracking. */
(() => {
	"use strict";
	const doc = document, root = doc.documentElement;
	root.classList.add("js");
	const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

	/* ---- the theme. A pre-paint script in the head has already applied any
	   saved choice, so this only has to handle the press and remember it. */
	const btn = doc.getElementById("themeBtn");
	if (btn) {
		const meta = doc.querySelector('meta[name="theme-color"]');
		const current = () =>
			root.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
		const sync = () => {
			const t = current();
			btn.textContent = t === "dark" ? "Light" : "Dark";
			btn.setAttribute("aria-pressed", t === "dark" ? "true" : "false");
			btn.setAttribute("aria-label", "Switch to " + (t === "dark" ? "light" : "dark") + " theme");
			if (meta) meta.content = t === "dark" ? "#0e1624" : "#ffffff";
		};
		btn.addEventListener("click", () => {
			const next = current() === "dark" ? "light" : "dark";
			root.dataset.theme = next;
			try { localStorage.setItem("theme", next); } catch (e) {}
			sync();
		});
		sync();
	}

	/* ---- arrival. The highlighter fills in, and blocks settle upward, only
	   once you have actually reached them. Without JS everything is simply
	   already in place: the .in state is the resting state. */
	const items = [...doc.querySelectorAll(".hl, .rv")];
	if (!items.length) return;
	if (reduce || !("IntersectionObserver" in window)) {
		items.forEach((el) => el.classList.add("in"));
		return;
	}
	const io = new IntersectionObserver((entries) => {
		entries.forEach((e) => {
			if (!e.isIntersecting) return;
			e.target.classList.add("in");
			io.unobserve(e.target);
		});
	}, { threshold: 0.3 });
	items.forEach((el) => io.observe(el));
})();
