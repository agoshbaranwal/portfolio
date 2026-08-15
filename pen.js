/* pen.js: the only script on the site, and the site never needs it.
   Everything here is delight on top of a page that is complete without JS:
   1. dark mode follows you across pages (and never flashes white),
   2. the desk lamp follows the reader across the page,
   3. the figures plate stamps down and counts up when you reach it,
   4. the guitar pick actually plays,
   5. the wax seal re-stamps a different life each time you press it,
   6. the cursor leaves ink ONLY where you are meant to write (Write to me),
   7. a long read gets a contents list in the margin that marks where you are.
   Every effect respects prefers-reduced-motion. No frameworks, no tracking. */
(() => {
	"use strict";
	const doc = document, root = doc.documentElement;
	root.classList.add("js");
	const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

	/* ---- the desk lamp. A pool of light that follows the reader, so the page
	   feels lit rather than printed. Pointer only, and free: it moves two custom
	   properties on one fixed element, nothing else on the page reflows. */
	const lamp = doc.querySelector(".lamp");
	if (lamp && matchMedia("(pointer: fine)").matches) {
		let lx = 0, ly = 0, queued = false;
		addEventListener("pointermove", (e) => {
			lx = e.clientX; ly = e.clientY;
			if (queued) return;
			queued = true;
			requestAnimationFrame(() => {
				lamp.style.setProperty("--mx", lx + "px");
				lamp.style.setProperty("--my", ly + "px");
				queued = false;
			});
		}, { passive: true });
	}

	/* ---- the figures plate stamps onto the paper when you reach it, and the
	   three numbers count up once. The strings are restored EXACTLY as authored
	   (the three approved figures are a checked invariant), so the count-up can
	   never change what the page says. IntersectionObserver is deliberately not
	   used: it does not fire for elements already on screen at load. */
	const plate = doc.querySelector(".figures");
	if (plate) {
		const nums = [];
		[...plate.querySelectorAll(".fig-n")].forEach((n) => {
			const walk = doc.createTreeWalker(n, NodeFilter.SHOW_TEXT);
			let t;
			while ((t = walk.nextNode())) {
				const m = t.nodeValue.match(/\d+/);
				if (!m) continue;
				nums.push({ node: t, full: t.nodeValue, to: +m[0],
					pre: t.nodeValue.slice(0, m.index), post: t.nodeValue.slice(m.index + m[0].length) });
				break;
			}
		});
		let counted = false;
		const count = () => {
			if (counted) return;
			counted = true;
			if (reduce || !nums.length) return;
			const t0 = performance.now(), DUR = 850;
			let done = false;
			/* the page may never show a figure that is not the real one, so the
			   authored strings are restored by a timer as well as by the frame
			   loop: if rAF is throttled or stalled the count still lands. */
			const settle = () => { done = true; nums.forEach((n) => { n.node.nodeValue = n.full; }); };
			const step = (now) => {
				if (done) return;
				const p = Math.min(1, (now - t0) / DUR), e = 1 - Math.pow(1 - p, 3);
				if (p >= 1) { settle(); return; }
				nums.forEach((n) => { n.node.nodeValue = n.pre + Math.round(n.to * e) + n.post; });
				requestAnimationFrame(step);
			};
			requestAnimationFrame(step);
			setTimeout(settle, DUR + 500);
			addEventListener("visibilitychange", () => { if (!doc.hidden) settle(); });
		};
		const sweep = () => {
			const r = plate.getBoundingClientRect();
			if (r.top > innerHeight * 0.92 || r.bottom < 0) return false;
			plate.classList.add("in");
			setTimeout(count, 260);
			return true;
		};
		if (!sweep()) {
			const on = () => requestAnimationFrame(() => { if (sweep()) removeEventListener("scroll", on); });
			addEventListener("scroll", on, { passive: true });
			addEventListener("load", on);
			setTimeout(on, 400);
		}
	}

	/* ---- the late show: persist, repaint the browser chrome, run the flicker */
	const night = doc.getElementById("night");
	const meta = doc.querySelector('meta[name="theme-color"]');
	const paint = () => { if (meta) meta.content = root.classList.contains("night") ? "#15161a" : "#fbfbf8"; };
	if (night) {
		if (night.checked && !root.classList.contains("night")) {
			/* the reader flipped the switch before this script arrived: honour it */
			root.classList.add("night");
			try { localStorage.setItem("late", "1"); } catch (e) {}
		} else {
			night.checked = root.classList.contains("night");
		}
		paint();
		night.addEventListener("change", () => {
			root.classList.toggle("night", night.checked);
			try { localStorage.setItem("late", night.checked ? "1" : "0"); } catch (e) {}
			paint();
			if (!reduce) {
				doc.body.classList.remove("flick");
				void doc.body.offsetWidth;
				doc.body.classList.add("flick");
				setTimeout(() => doc.body.classList.remove("flick"), 650);
			}
		});
	}

	/* ---- the pick really plays: a soft plucked D chord, Karplus-Strong style.
	   Only ever on a direct press, never ambient, slightly different each time. */
	let ctx;
	const pluck = (freq, when, gain) => {
		const sr = ctx.sampleRate, n = Math.max(2, Math.round(sr / freq));
		const len = Math.round(sr * 1.3);
		const buf = ctx.createBuffer(1, len, sr), d = buf.getChannelData(0);
		for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
		for (let i = n; i < len; i++) d[i] = (d[i - n] + d[i - n + 1 < len ? i - n + 1 : i - n]) * 0.4965;
		const src = ctx.createBufferSource(); src.buffer = buf;
		const vol = ctx.createGain();
		vol.gain.setValueAtTime(gain, when);
		vol.gain.exponentialRampToValueAtTime(0.001, when + 1.2);
		src.connect(vol); vol.connect(ctx.destination);
		src.start(when); src.stop(when + 1.25);
	};
	const pick = doc.querySelector(".keep-pick");
	if (pick) pick.addEventListener("click", () => {
		try { ctx = ctx || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
		if (ctx.state === "suspended") ctx.resume();
		const t = ctx.currentTime + 0.02;
		[146.83, 220.0, 293.66, 369.99].forEach((f, i) => {
			pluck(f * (1 + (Math.random() - 0.5) * 0.004), t + i * (0.05 + (Math.random() - 0.5) * 0.014), 0.08);
		});
	});

	/* ---- press the wax seal, it re-stamps with a different life: the nib
	   (writing), a chef's toque (cooking), a pick (music), a TV, a paper plane
	   (travel). Cycles on every click/Enter; with JS off it rests on the nib. */
	const seal = doc.querySelector(".seal-btn");
	const sealWrap = seal && seal.closest(".seam-wrap");
	const emblems = [...doc.querySelectorAll(".seam .emblem")];
	if (seal && sealWrap && emblems.length) {
		const labels = seal.dataset.labels ? seal.dataset.labels.split("|") : [];
		let i = emblems.findIndex(e => e.classList.contains("is-active"));
		if (i < 0) i = 0;
		seal.addEventListener("click", () => {
			emblems[i].classList.remove("is-active");
			i = (i + 1) % emblems.length;
			emblems[i].classList.add("is-active");
			if (labels[i]) {
				seal.setAttribute("aria-label", labels[i]);
				const live = doc.querySelector(".seal-live");
				if (live) live.textContent = labels[i].replace("A wax seal pressed with ", "The seal now shows ").replace(" Press to re-stamp it.", "");
			}
			if (!reduce) {
				sealWrap.classList.remove("restamp");
				void sealWrap.offsetWidth;
				sealWrap.classList.add("restamp");
				setTimeout(() => sealWrap.classList.remove("restamp"), 480);
			}
		});
	}

	/* ---- a long piece gets a contents list, and the list marks where you are.
	   The anchors already work without this; all it adds is knowing your place. */
	const toc = doc.querySelector(".toc");
	if (toc) {
		const links = [...toc.querySelectorAll("a")];
		const heads = links.map(a => doc.getElementById(decodeURIComponent(a.hash.slice(1))));
		if (heads.every(Boolean) && heads.length) {
			let queued = false;
			const mark = () => {
				let at = 0;
				heads.forEach((h, i) => { if (h.getBoundingClientRect().top <= 140) at = i; });
				links.forEach((a, i) => {
					a.classList.toggle("is-here", i === at);
					if (i === at) a.setAttribute("aria-current", "true"); else a.removeAttribute("aria-current");
				});
			};
			addEventListener("scroll", () => {
				if (queued) return;
				queued = true;
				requestAnimationFrame(() => { mark(); queued = false; });
			}, { passive: true });
			mark();
		}
	}

	/* ---- pass it on: the reader sends the page along. Share sheet on devices
	   that have one, the clipboard elsewhere. The button only exists with JS. */
	const pass = doc.querySelector(".pass-btn");
	if (pass) pass.addEventListener("click", async () => {
		const url = location.origin + location.pathname;
		if (navigator.share) {
			try { await navigator.share({ title: doc.title, url }); } catch (e) {}
			return;
		}
		try { await navigator.clipboard.writeText(url); } catch (e) { return; }
		const done = doc.querySelector(".pass-done");
		if (done) {
			done.classList.add("shown");
			setTimeout(() => done.classList.remove("shown"), 1800);
		}
	});

	/* ---- the ink trail means one thing: here you can write. So it appears in
	   exactly ONE place, the Write to me section, and nowhere else on any page.
	   The pen only leaves ink where the reader is invited to put words down. */
	const writezone = doc.querySelector("#write");
	if (writezone && !reduce && matchMedia("(pointer: fine)").matches) {
		const c = doc.createElement("canvas");
		c.className = "inktrail";
		doc.body.appendChild(c);
		const g = c.getContext("2d");
		let dpr = Math.min(window.devicePixelRatio || 1, 2);
		const size = () => { dpr = Math.min(window.devicePixelRatio || 1, 2); c.width = innerWidth * dpr; c.height = innerHeight * dpr; };
		size();
		addEventListener("resize", size);
		const penColor = () => (getComputedStyle(root).getPropertyValue("--pen").trim() || "#1d3a63");
		let col = penColor();
		if (night) night.addEventListener("change", () => setTimeout(() => { col = penColor(); }, 450));
		const LIFE = 620;
		let pts = [], raf = 0;
		const tick = () => {
			const now = performance.now();
			pts = pts.filter(p => now - p.t < LIFE);
			g.clearRect(0, 0, c.width, c.height);
			g.lineCap = g.lineJoin = "round";
			g.strokeStyle = col;
			for (let i = 1; i < pts.length; i++) {
				const a = pts[i - 1], b = pts[i];
				if (b.t - a.t > 90) continue;
				const age = (now - b.t) / LIFE;
				g.globalAlpha = 0.36 * (1 - age);
				g.lineWidth = Math.max(0.5, (1.7 - age) * dpr);
				g.beginPath();
				g.moveTo(a.x * dpr, a.y * dpr);
				g.lineTo(b.x * dpr, b.y * dpr);
				g.stroke();
			}
			raf = pts.length > 1 ? requestAnimationFrame(tick) : 0;
			if (!raf) g.clearRect(0, 0, c.width, c.height);
		};
		addEventListener("pointermove", (e) => {
			if (e.pointerType !== "mouse" && e.pointerType !== "pen") return;
			const r = writezone.getBoundingClientRect();
			if (e.clientY < r.top || e.clientY > r.bottom || e.clientX < r.left || e.clientX > r.right) return;
			pts.push({ x: e.clientX, y: e.clientY, t: performance.now() });
			if (!raf) raf = requestAnimationFrame(tick);
		}, { passive: true });
	}
})();
