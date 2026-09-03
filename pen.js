/* pen.js: the only script on the site, and the site never needs it.
   Everything here is delight or convenience on top of pages that are complete
   without it:
     1. the theme choice follows you across pages and never flashes,
     2. the highlighter draws itself on when you reach the thing it marks,
        and blocks rise into place as they arrive,
     3. on a phone, the two things a visitor came for stay in reach once the
        hero has scrolled away,
     4. the rails on the home page and the essay mark where you are,
     5. a reading line shows how far through an essay you have got,
     6. the contact address can be copied, and says so in the marker.
   Every one of them respects prefers-reduced-motion, and with the script off
   the pages are exactly what they were: .in is the resting state, the dock and
   the reading line are display:none until this file adds html.js, and the copy
   control is hidden because the address beside it is already a mail link.
   No frameworks, no tracking. */
(() => {
	"use strict";
	const doc = document, root = doc.documentElement;
	root.classList.add("js");
	const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
	const $ = (s, c) => (c || doc).querySelector(s);
	const $$ = (s, c) => [...(c || doc).querySelectorAll(s)];

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

	/* ---- arrival. The highlighter fills in, blocks settle upward and the
	   weekly loop walks its four stops, only once you have actually reached
	   them. Without JS everything is simply already in place. */
	const items = $$(".hl, .rv");
	if (items.length) {
		if (reduce || !("IntersectionObserver" in window)) {
			items.forEach((el) => el.classList.add("in"));
		} else {
			const io = new IntersectionObserver((entries) => {
				entries.forEach((e) => {
					if (!e.isIntersecting) return;
					e.target.classList.add("in");
					io.unobserve(e.target);
				});
			}, { threshold: 0.3 });
			items.forEach((el) => io.observe(el));
		}
	}

	/* ---- the phone dock. The masthead drops the CV button below 640px and the
	   hero takes the email with it when it scrolls, so both come back along the
	   bottom edge. It is only ever built on a phone, and it is inert until it
	   is up, so nothing invisible is in the tab order. */
	const dock = doc.getElementById("dock"), heroAct = $(".hero-act");
	if (dock && heroAct && "IntersectionObserver" in window) {
		const links = $$("a", dock);
		const setUp = (up) => {
			if (dock.classList.contains("up") === up) return;
			dock.classList.toggle("up", up);
			dock.setAttribute("aria-hidden", up ? "false" : "true");
			links.forEach((a) => a.setAttribute("tabindex", up ? "0" : "-1"));
		};
		new IntersectionObserver(
			(es) => es.forEach((e) => setUp(!e.isIntersecting && e.boundingClientRect.top < 0)),
			{ threshold: 0 }
		).observe(heroAct);
	}

	/* ---- the two rails. Same job on the home page and on an essay: mark the
	   section being read. An IntersectionObserver on the headings themselves was
	   the first attempt and it was wrong: a heading is a few pixels tall, so at
	   most scroll positions none of them is inside the observer's band and the
	   rail marks nothing. This reads position instead, and the answer is simply
	   the last heading that has passed the reading line. */
	const rail = (railSel) => {
		const links = [...doc.querySelectorAll(railSel + " a")];
		if (!links.length) return;
		const targets = links
			.map((a) => ({ a, el: doc.getElementById(decodeURIComponent(a.hash.slice(1))) }))
			.filter((t) => t.el);
		if (!targets.length) return;
		let last = null;
		const mark = () => {
			const line = innerHeight * 0.34;
			let cur = targets[0];
			for (const t of targets) if (t.el.getBoundingClientRect().top <= line) cur = t;
			if (cur === last) return;
			last = cur;
			links.forEach((l) => l === cur.a
				? l.setAttribute("aria-current", "true")
				: l.removeAttribute("aria-current"));
		};
		let ticking = false;
		addEventListener("scroll", () => {
			if (!ticking) { ticking = true; requestAnimationFrame(() => { ticking = false; mark(); }); }
		}, { passive: true });
		addEventListener("resize", mark, { passive: true });
		mark();
	};
	rail(".home-rail");
	rail(".toc");

	/* ---- the reading line. Scroll position over the scrollable height, read
	   on a frame so it never blocks the scroll itself. */
	const bar = doc.getElementById("readbar");
	if (bar) {
		let ticking = false;
		const draw = () => {
			const h = doc.documentElement.scrollHeight - innerHeight;
			const p = h > 0 ? Math.min(1, Math.max(0, scrollY / h)) : 0;
			bar.style.transform = "scaleX(" + p.toFixed(4) + ")";
			ticking = false;
		};
		addEventListener("scroll", () => {
			if (!ticking) { ticking = true; requestAnimationFrame(draw); }
		}, { passive: true });
		addEventListener("resize", draw, { passive: true });
		draw();
	}

	/* ---- copy the address, and say so in the marker. The clipboard API is
	   refused in some contexts, so there is a second way through and a visible
	   failure: the address beside this button is a mail link either way, and the
	   control only appears at all once one of the two paths is available. */
	const copy = doc.getElementById("copyMail");
	if (copy) {
		const label = $(".cm", copy), tag = $(".ci", copy), was = tag.textContent;
		const legacy = (text) => {
			const ta = doc.createElement("textarea");
			ta.value = text; ta.setAttribute("readonly", "");
			ta.style.position = "fixed"; ta.style.top = "-1000px";
			doc.body.appendChild(ta); ta.select();
			let ok = false;
			try { ok = doc.execCommand("copy"); } catch (e) {}
			doc.body.removeChild(ta);
			return ok;
		};
		if (navigator.clipboard || doc.queryCommandSupported) {
			copy.dataset.on = "";
			copy.addEventListener("click", async () => {
				const text = copy.dataset.copy || "";
				let ok = false;
				try { await navigator.clipboard.writeText(text); ok = true; } catch (e) { ok = legacy(text); }
				if (ok) {
					copy.classList.add("done");
					tag.textContent = "Copied";
					label.textContent = text;
					setTimeout(() => {
						copy.classList.remove("done"); tag.textContent = was;
						label.textContent = "Copy the address";
					}, 2600);
				} else {
					tag.textContent = "Use the link";
					setTimeout(() => { tag.textContent = was; }, 2600);
				}
			});
		}
	}
})();
