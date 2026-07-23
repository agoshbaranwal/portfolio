/* pen.js: the only script on the site, and the site never needs it.
   Everything here is delight on top of a page that is complete without JS:
   1. the late show follows you across pages (and never flashes white),
   2. the guitar pick actually plays,
   3. the signature signs again when you tap the name,
   4. the cursor leaves a fading line of ink across the opening.
   Every effect respects prefers-reduced-motion. No frameworks, no tracking. */
(() => {
	"use strict";
	const doc = document, root = doc.documentElement;
	root.classList.add("js");
	const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

	/* ---- the late show: persist, repaint the browser chrome, run the flicker */
	const night = doc.getElementById("night");
	const meta = doc.querySelector('meta[name="theme-color"]');
	const paint = () => { if (meta) meta.content = root.classList.contains("night") ? "#15161a" : "#fbfbf8"; };
	if (night) {
		night.checked = root.classList.contains("night");
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

	/* ---- tap the name, he signs it again */
	const wrap = doc.querySelector(".namewrap");
	if (wrap && !reduce) wrap.addEventListener("click", () => {
		wrap.classList.remove("sign-again");
		void wrap.offsetWidth;
		wrap.classList.add("sign-again");
		setTimeout(() => wrap.classList.remove("sign-again"), 2000);
	});

	/* ---- the ink trail: the pen follows the reader across the opening only.
	   Mouse and stylus, motion-tolerant readers, and nowhere near the prose
	   below the hero: restraint is the feature. */
	const opening = doc.querySelector(".opening");
	if (opening && !reduce && matchMedia("(pointer: fine)").matches) {
		const c = doc.createElement("canvas");
		c.className = "inktrail";
		doc.body.appendChild(c);
		const g = c.getContext("2d");
		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		const size = () => { c.width = innerWidth * dpr; c.height = innerHeight * dpr; };
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
			const r = opening.getBoundingClientRect();
			if (e.clientY < r.top || e.clientY > r.bottom) return;
			pts.push({ x: e.clientX, y: e.clientY, t: performance.now() });
			if (!raf) raf = requestAnimationFrame(tick);
		}, { passive: true });
	}
})();
