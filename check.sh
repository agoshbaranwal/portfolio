#!/bin/bash
# Executable invariants for the portfolio. Run from the repo root after every change:
#   ./check.sh            checks everything
#   ./check.sh <slug>     also checks a newly published post is wired into every file
#
# Rebuilt 2026-09-01 for the new site (Home / Blog / About me / CV). Rules 3, 6, 7
# and 5h were RETIRED with the owner's explicit sign-off that day: he asked for a
# stated years-of-experience figure, and the locked project order, the locked
# headings and the "still drying" freshness marker all belonged to a design that
# no longer exists. Every other rule below is still enforced.
cd "$(dirname "$0")"
fail=0
PAGES="index.html about.html cv.html 404.html blog/index.html blog/customer-love-is-a-lagging-indicator.html projects/witness.html"

# ---------------------------------------------------------------- 1. styling
# One stylesheet. No <style> blocks, no inline style attributes.
if grep -l "<style" $PAGES 2>/dev/null; then
	echo "FAIL: <style> tag found in a shipped page (all styling belongs in site.css)"; fail=1
fi
if grep -lE '<[a-z][^>]* style="' $PAGES 2>/dev/null; then
	echo "FAIL: inline style attribute found (add a class to site.css instead)"; fail=1
fi

# ---------------------------------------------------------------- 2. em dashes
if grep -l "—" $PAGES post-template.html feed.xml site.css 2>/dev/null; then
	echo "FAIL: em dash found in copy"; fail=1
fi

# --------------------------------------------------- 2b. the highlighted figures
# Exactly four numbers are highlighted on the homepage, each exactly once, and each
# one is wrapped in the highlighter. Nothing else may wear it.
python3 - <<'PY' || fail=1
import re, sys
s = open("index.html", encoding="utf-8").read()
want = ["10x ROAS", "$3M", "$100k", "50,000+"]
marked = re.findall(r'<span class="hl">([^<]*)</span>', s)
bad = 0
if marked != want:
	print(f"FAIL: the highlighter marks {marked}, it must mark exactly {want}"); bad = 1
text = re.sub(r"<[^>]+>", " ", re.sub(r"(?s)<head.*?</head>|<script.*?</script>|<svg.*?</svg>", "", s))
for fig in want:
	n = text.count(fig)
	if n != 1:
		print(f"FAIL: figure '{fig}' appears {n} times in visible copy (must be exactly 1)"); bad = 1
# No percentage stats. The IIT percentile is written "99.96th percentile" with
# no % sign, on his instruction 2026-09-01, so it passes and should stay.
for pct in re.findall(r"\d+%", text):
	print(f"FAIL: percentage stat '{pct}' in homepage copy (owner ruled: no percentages)"); bad = 1
sys.exit(bad)
PY

# ---------------------------------------------------- 3. RETIRED (2026-09-01)
# Was: never state a number of years of experience. The owner now asks for
# "ESADE MBA, 5+ years of experience driving growth in startups and scaleups".

# ------------------------------------------------------------ 4. link hygiene
# Internal links are extensionless (vercel.json cleanUrls). Feed and assets exempt.
if grep -hoE 'href="/[^"]*\.html"' $PAGES 2>/dev/null; then
	echo "FAIL: internal link carries .html (breaks cleanUrls style)"; fail=1
fi

# ------------------------------------------------------------- 5. a new post
if [ -n "$1" ]; then
	[ -f "blog/$1.html" ] || { echo "FAIL: blog/$1.html missing"; fail=1; }
	for f in blog/index.html feed.xml sitemap.xml; do
		grep -q "$1" "$f" || { echo "FAIL: slug '$1' not referenced in $f"; fail=1; }
	done
fi

# 5b. Every anchor must actually be a link. A swallowed quote (class="x href="/")
#     tokenises into a styled element with NO href: it looks live and is dead.
#     This shipped once. It never ships again.
python3 - <<'PY' || fail=1
import sys, glob
from html.parser import HTMLParser
class P(HTMLParser):
	def __init__(self): super().__init__(); self.bad = []
	def handle_starttag(self, tag, attrs):
		if tag != "a": return
		d = dict(attrs)
		if not (d.get("href") or "").strip():
			self.bad.append((self.getpos()[0], "no href", attrs))
		for k, _ in attrs:
			if '"' in k or k.endswith("href="):
				self.bad.append((self.getpos()[0], "malformed attribute", attrs))
bad = 0
for f in sorted(glob.glob("*.html") + glob.glob("blog/*.html") + glob.glob("projects/*.html")):
	if f == "post-template.html": continue
	p = P(); p.feed(open(f, encoding="utf-8").read())
	for line, why, attrs in p.bad:
		print(f"FAIL: {f}:{line} anchor {why}: {attrs}"); bad += 1
sys.exit(1 if bad else 0)
PY

# 5c. The location ban: the city he lives in never ships as HIS location. The one
#     permitted use, on his instruction 2026-09-01, is the name of the business
#     school campus: "ESADE Barcelona" is a credential, not an address. Any other
#     mention still fails.
python3 - <<'PY' || fail=1
import re, sys, glob
bad = 0
for f in sorted(glob.glob("*.html") + glob.glob("blog/*.html") + glob.glob("projects/*.html")
                + ["feed.xml", "sitemap.xml", "robots.txt"]):
	if f == "post-template.html": continue
	try: s = open(f, encoding="utf-8").read()
	except OSError: continue
	for m in re.finditer(r"barcelona", s, re.I):
		before = s[max(0, m.start() - 6):m.start()]
		if re.search(r"esade\s*$", before, re.I): continue
		print(f"FAIL: {f} names the banned location outside 'ESADE Barcelona'"); bad += 1
sys.exit(1 if bad else 0)
PY

# 5d. Every internal link and asset must resolve to a real file.
python3 - <<'PY' || fail=1
import re, glob, os, sys
bad = 0
def target(h):
	h = h.split("#")[0].split("?")[0]
	if not h or not h.startswith("/") or h.startswith("//"): return None
	if h == "/": return "index.html"
	p = h.lstrip("/")
	for c in (p, p + ".html", p + "/index.html"):
		if os.path.exists(c): return c
	return "MISSING:" + h
for f in glob.glob("*.html") + glob.glob("blog/*.html") + glob.glob("projects/*.html"):
	if f == "post-template.html": continue
	for h in re.findall(r'(?:href|src)="([^"]+)"', open(f, encoding="utf-8").read()):
		t = target(h)
		if t and t.startswith("MISSING"):
			print(f"FAIL: {f} links to {h} which resolves to no file"); bad += 1
sys.exit(1 if bad else 0)
PY

# 5e. The blog index must lead with the newest item in the feed.
newest=$(grep -o '<link>https://agoshportfolio.vercel.app/blog/[^<]*</link>' feed.xml | head -1 | sed 's#.*app##;s#</link>##')
if [ -n "$newest" ]; then
	grep -q "$newest" blog/index.html || { echo "FAIL: /blog does not link the newest feed item '$newest'"; fail=1; }
else
	echo "FAIL: feed.xml lists no post"; fail=1
fi

# 5f. Max two tags per post page.
for f in blog/*.html; do
	[ "$f" = "blog/index.html" ] && continue
	n=$(grep -o 'class="tag"' "$f" | wc -l | tr -d ' ')
	[ "$n" -le 2 ] || { echo "FAIL: $f carries $n tags (max 2)"; fail=1; }
done

# 5g. The deploy fence: private files must be listed in .vercelignore
#     (Vercel ignores .gitignore entirely once a .vercelignore exists).
for pat in ".notes" ".env" "lab" "incoming"; do
	grep -q "$pat" .vercelignore || { echo "FAIL: .vercelignore does not fence $pat"; fail=1; }
done

# --------------------------------------------------- 5h, 6, 7. RETIRED (2026-09-01)
# 5h was the "still drying" freshness marker, 6 the locked project order, 7 the
# locked section headings. All three policed a page that has been replaced.

# 7b. Banned interface words: the old aphoristic voice may not return to the UI.
if grep -rniE "late show|the notebook|still drying|still on the bench|pass it on|what is in here|the short version|where this comes from|written with one pen|the front page|the rest of the notebook|things i am building" $PAGES 2>/dev/null; then
	echo "FAIL: a retired interface label is back (see the 2026-08-15 copy rule)"; fail=1
fi

# 7c. Every shipped page must be structurally balanced. Two stray closers once put
#     a link outside its own grid column and silently unbalanced the document.
python3 - <<'PY' || fail=1
import sys, glob, re
bad = 0
TAGS = ["div", "article", "section", "main", "nav", "header", "figure", "ul", "ol", "p", "li"]
for f in sorted(glob.glob("*.html") + glob.glob("blog/*.html") + glob.glob("projects/*.html")):
	if f == "post-template.html": continue
	s = open(f, encoding="utf-8").read()
	s = re.sub(r"(?s)<script.*?</script>|<svg.*?</svg>|<!--.*?-->", "", s)
	for t in TAGS:
		o, c = len(re.findall(r"<%s[\s>]" % t, s)), len(re.findall(r"</%s>" % t, s))
		if o != c:
			print(f"FAIL: {f} has {o} <{t}> and {c} </{t}>"); bad += 1
sys.exit(1 if bad else 0)
PY

# ------------------------------------------- 8. no full stops in interface copy
# The owner's rule, 2026-09-01: headings, labels, captions and button text carry no
# full stops. Long-form prose does, so the essay and the CV summary are exempt.
python3 - <<'PY' || fail=1
import re, sys
bad = 0
for f in ["index.html", "about.html", "404.html", "blog/index.html", "projects/witness.html"]:
	s = open(f, encoding="utf-8").read()
	s = re.sub(r"(?s)<head.*?</head>|<script.*?</script>|<svg.*?</svg>|<!--.*?-->", "", s)
	for hit in re.findall(r"[A-Za-z0-9)]\.(?=\s|$)", re.sub(r"<[^>]+>", " ", s), re.M):
		print(f"FAIL: {f} interface copy contains a full stop near '{hit}'"); bad += 1
sys.exit(1 if bad else 0)
PY

# ------------------------------------------------------- 9. one typeface, self-hosted
if grep -l "fonts.googleapis.com\|fonts.gstatic.com" $PAGES site.css 2>/dev/null; then
	echo "FAIL: a remote font request (Montserrat is self-hosted at /fonts/montserrat.woff2)"; fail=1
fi
[ -f fonts/montserrat.woff2 ] || { echo "FAIL: fonts/montserrat.woff2 missing"; fail=1; }
n=$(grep -oE 'font-family:[^;}]*' site.css | grep -vc 'var(--font)\|"Montserrat"')
[ "$n" = "0" ] || { echo "FAIL: site.css names $n typeface other than Montserrat"; fail=1; }

# ------------------------------------------------ 10. every outbound link is previewed
# The owner's trust rule: a link off this site always shows what is behind it, either
# a screenshot or a quiet slot waiting for one. No bare URLs.
python3 - <<'PY' || fail=1
import re, sys
s = open("index.html", encoding="utf-8").read()
bad = 0
cards = re.findall(r'(?s)<(a|span) class="proj[^"]*"[^>]*>(.*?)</\1>', s)
if len(cards) < 4:
	print(f"FAIL: only {len(cards)} project cards parsed"); bad = 1
for i, (_, inner) in enumerate(cards, 1):
	if not re.search(r'<img class="shot"|<span class="shot"', inner):
		print(f"FAIL: project card {i} ships neither a preview nor a slot for one"); bad = 1
for m in re.finditer(r'(?s)<a class="link-card".*?</a>', s):
	if "badge" not in m.group(0):
		print("FAIL: a link card ships without its site badge"); bad = 1
sys.exit(bad)
PY

# ------------------------------------- 10b. no scaffolding text ever ships
# The ONE deliberate exception is the .notice at the top of the homepage, which
# Agosh asked for on 2026-09-01: it names what is missing in plain words instead
# of writing "coming soon" into each empty slot. Delete it when the last of the
# photographs, press links and event dates lands.
# Placeholder words shipped once ("Outlet", "year", "event name" printed on the
# live page). An empty slot is a quiet panel with nothing written on it, never a
# label saying something is missing.
if grep -rniE "to be added|coming soon|placeholder|lorem ipsum|\bTBD\b|\bTODO\b|class=\"todo\"" $PAGES 2>/dev/null; then
	echo "FAIL: placeholder scaffolding is visible in a shipped page"; fail=1
fi

# --------------------------------------------------- 11. every page is shareable
for f in index.html about.html cv.html blog/index.html blog/customer-love-is-a-lagging-indicator.html projects/witness.html; do
	for tag in 'rel="canonical"' 'property="og:image"' 'name="description"'; do
		grep -q "$tag" "$f" || { echo "FAIL: $f is missing $tag"; fail=1; }
	done
done

[ $fail -eq 0 ] && echo "OK: all invariants hold"
exit $fail
