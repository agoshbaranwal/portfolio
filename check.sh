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
PAGES="index.html about.html cv.html contact.html 404.html blog/index.html blog/customer-love-is-a-lagging-indicator.html projects/witness.html work/index.html work/efeed-paid.html work/abicart-growth.html work/abicart-retention.html"

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
for f in sorted([f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html") if not f.split("/")[-1].startswith("_")]):
	if f == "post-template.html": continue
	p = P(); p.feed(open(f, encoding="utf-8").read())
	for line, why, attrs in p.bad:
		print(f"FAIL: {f}:{line} anchor {why}: {attrs}"); bad += 1
sys.exit(1 if bad else 0)
PY

# 5i. EVERY TAG'S ATTRIBUTES MUST PARSE, not just an anchor's. Rule 5b has caught
# a swallowed quote on <a> since the first week; on 2026-09-03 a script spliced
# <img> width/height with shifting offsets and produced width=6400" and
# widt780390". Every page still passed, because nothing looked at images. This
# lane parses every tag on every page and fails on an attribute name that is not
# a name, a duplicate attribute, or an <img> without alt.
python3 - <<'TAGCHECK' || fail=1
import glob, re, sys
from html.parser import HTMLParser
class P(HTMLParser):
	def __init__(self, f): super().__init__(); self.f=f; self.bad=[]
	def handle_starttag(self, tag, attrs):
		seen=set()
		for k, v in attrs:
			if not re.fullmatch(r'[A-Za-z_:][-A-Za-z0-9_:.]*', k):
				self.bad.append((self.getpos()[0], f"<{tag}> attribute name {k!r} is malformed"))
			if k in seen:
				self.bad.append((self.getpos()[0], f"<{tag}> repeats the attribute {k!r}"))
			seen.add(k)
		d=dict(attrs)
		if tag=="img":
			if d.get("alt") is None and d.get("aria-hidden")!="true":
				self.bad.append((self.getpos()[0], "<img> has no alt and is not aria-hidden"))
			for dim in ("width","height"):
				if dim in d and not re.fullmatch(r'\d+', d[dim] or ""):
					self.bad.append((self.getpos()[0], f"<img {dim}={d[dim]!r}> is not a plain number"))
bad=0
for f in sorted([f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html") if not f.split("/")[-1].startswith("_")]):
	if f=="post-template.html": continue
	p=P(f); p.feed(open(f, encoding="utf-8").read())
	for line, why in p.bad:
		print(f"FAIL: {f}:{line} {why}"); bad+=1
sys.exit(1 if bad else 0)
TAGCHECK

# 5c. The location ban: the city he lives in never ships as HIS location. The one
#     permitted use, on his instruction 2026-09-01, is the name of the business
#     school campus: "ESADE Barcelona" is a credential, not an address. Any other
#     mention still fails.
python3 - <<'PY' || fail=1
import re, sys, glob
bad = 0
for f in sorted([f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html") if not f.split("/")[-1].startswith("_")]
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
for f in [f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html") if not f.split("/")[-1].startswith("_")]:
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
for f in sorted([f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html") if not f.split("/")[-1].startswith("_")]):
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
# full stops. Long-form prose does, so the essay, the CV summary, the writing on
# the About register and the explanations under each design decision on the
# Witness page are exempt. That last one was added 2026-09-01 for a reason worth
# keeping: with no full stops allowed, every explanation had to be one long
# comma-spliced sentence, and comma-spliced sentences are exactly what made that
# copy read as written rather than said. Headings, captions, leads and buttons on
# every page are still checked.
python3 - <<'PY' || fail=1
import re, sys
bad = 0
for f in ["index.html", "about.html", "contact.html", "404.html", "blog/index.html", "projects/witness.html"]:
	s = open(f, encoding="utf-8").read()
	s = re.sub(r"(?s)<head.*?</head>|<script.*?</script>|<svg.*?</svg>|<!--.*?-->", "", s)
	s = re.sub(r'(?s)<div class="hand[^"]*">.*?</div>', "", s)
	s = re.sub(r'(?s)<div class="txt">.*?</div>', "", s)
	s = re.sub(r'(?s)<p class="gate-note">.*?</p>', "", s)
	for hit in re.findall(r"[A-Za-z0-9)]\.(?=\s|$)", re.sub(r"<[^>]+>", " ", s), re.M):
		print(f"FAIL: {f} interface copy contains a full stop near '{hit}'"); bad += 1
sys.exit(1 if bad else 0)
PY

# ------------------------------------------ 9. every typeface is a file in here
# Montserrat everywhere, Gochi Hand on the About register, and five wordmark
# faces that exist only to set one project name each on the homepage cards (his
# instruction, 2026-09-01). Each wordmark file is subsetted to the letters of its
# own name, which is why five of them weigh 10KB between them. The rules: no
# request may leave for a font, every declared face must have its file, the hand
# stays on .hand, and a wordmark face stays on .p-name so none can leak into
# general use.
if grep -l "fonts.googleapis.com\|fonts.gstatic.com" $PAGES site.css 2>/dev/null; then
	echo "FAIL: a remote font request (every face is self-hosted under /fonts)"; fail=1
fi
python3 - <<'FONTCHECK' || fail=1
import re, os, sys
css = open("site.css", encoding="utf-8").read()
bad = 0
for fam, url in re.findall(r'@font-face\{[^}]*font-family:"([^"]+)"[^}]*url\("([^"]+)"', css):
	if not os.path.exists(url.lstrip("/")):
		print(f"FAIL: @font-face {fam} points at {url}, which is not in the repo"); bad = 1
declared = set(re.findall(r'@font-face\{[^}]*font-family:"([^"]+)"', css))
generic = {"serif","sans-serif","monospace","cursive","system-ui","ui-monospace","-apple-system",
           "BlinkMacSystemFont","Segoe UI","Roboto","Helvetica","Arial","Helvetica Neue","Georgia",
           "Didot","Menlo","Segoe Script","Segoe Print","Bradley Hand"}
for decl in re.findall(r'font-family:([^;}]+)', css):
	if "var(--" in decl or decl.strip() == "inherit": continue
	for part in decl.split(","):
		fam = part.strip().strip("'\"")
		if fam and fam not in generic and fam not in declared:
			print(f"FAIL: font-family names {fam!r}, which no @font-face in this repo declares"); bad = 1
for n, line in enumerate(css.split("\n"), 1):
	if "var(--hand)" in line and not line.startswith(".hand{"):
		print(f"FAIL: site.css:{n} uses var(--hand) outside .hand"); bad = 1
	m = re.match(r'\s*([^{]*)\{[^}]*font-family:"(WM [^"]+)"', line)
	if m and not line.startswith("@font-face") and ".wm-" not in m.group(1):
		print(f"FAIL: site.css:{n} applies the wordmark face {m.group(2)!r} without a wm- class"); bad = 1
sys.exit(bad)
FONTCHECK
# 9b. A FONT URL CARRIES ITS OWN CONTENT HASH, and this one is not theoretical.
# vercel.json serves /fonts/* with `max-age=31536000, immutable`, which promises
# the bytes at that URL will never change. On 2026-09-01 the wordmark subsets
# were re-cut to cover a whole card instead of just its name, under the SAME
# filenames, so every browser that had loaded the site in between kept the
# 7-glyph file for a year: most letters fell back to Montserrat mid-word and the
# cards rendered in two typefaces at once. Content-addressed names make the
# promise honest, and this lane fails the moment a file's bytes and its name
# disagree.
python3 - <<'HASHCHECK' || fail=1
import hashlib, glob, os, re, sys
bad = 0
for f in sorted(glob.glob("fonts/*.woff2")):
	m = re.search(r'\.([0-9a-f]{8})\.woff2$', os.path.basename(f))
	if not m:
		print(f"FAIL: {f} has no content hash in its name, but /fonts is served immutable"); bad = 1; continue
	real = hashlib.sha256(open(f, "rb").read()).hexdigest()[:8]
	if real != m.group(1):
		print(f"FAIL: {f} is named {m.group(1)} but its bytes hash to {real}; rename it or the cache serves the old file"); bad = 1
sys.exit(bad)
HASHCHECK

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
for f in index.html about.html cv.html contact.html blog/index.html blog/customer-love-is-a-lagging-indicator.html projects/witness.html work/index.html work/efeed-paid.html work/abicart-growth.html work/abicart-retention.html; do
	for tag in 'rel="canonical"' 'property="og:image"' 'name="description"'; do
		grep -q "$tag" "$f" || { echo "FAIL: $f is missing $tag"; fail=1; }
	done
done


# --------------------------------------------------------- 12. page weight
# The site is fast because it is small, and it stays small only if something
# says so out loud. Two numbers: what has to arrive before the first paint, and
# what the whole page costs once every picture has landed. Every <img> must also
# declare its own width and height, which is what stops the page jumping about
# as the pictures arrive.
python3 - <<'PY' || fail=1
import os, re, sys
bad = 0
BLOCK, TOTAL = 150_000, 900_000
def size(p):
	p = p.split("?")[0].lstrip("/")
	return os.path.getsize(p) if os.path.exists(p) else 0
for page in ("index.html", "cv.html", "projects/witness.html", "blog/customer-love-is-a-lagging-indicator.html"):
	s = open(page, encoding="utf-8").read()
	block = os.path.getsize(page) + size("site.css")
	block += sum(size(u) for u in re.findall(r'<link rel="preload" href="([^"]+)"', s))
	total = block + size("pen.js")
	# one variant per picture: a browser fetches the avif OR the jpeg, never both
	seen = set()
	for u in re.findall(r'(?:src|srcset)="([^"]+)"', s):
		if not u.startswith("/") or u.endswith(".html"): continue
		best = u[:-4] + ".avif" if u.endswith(".jpg") and os.path.exists(u.lstrip("/")[:-4] + ".avif") else u
		if best in seen: continue
		seen.add(best); total += size(best)
	if block > BLOCK:
		print(f"FAIL: {page} needs {block//1024}KB before it can paint (limit {BLOCK//1024}KB)"); bad = 1
	if total > TOTAL:
		print(f"FAIL: {page} weighs {total//1024}KB in all (limit {TOTAL//1024}KB)"); bad = 1
	for tag in re.findall(r"<img [^>]*>", s):
		if 'width="' not in tag or 'height="' not in tag:
			print(f"FAIL: {page} has an <img> with no width or height: {tag[:80]}"); bad = 1
sys.exit(bad)
PY

# ------------------------------------------------- 13. the footer cannot rot
# Every page says when the site was last updated. They must all say the same
# thing, it may not be in the future, and it may not be more than a year old:
# a date that quietly ages is worse than no date, because it is read as a claim.
python3 - <<'PY' || fail=1
import glob, re, sys, datetime
bad = 0; stamps = {}
MONTHS = {m: i for i, m in enumerate(
	"January February March April May June July August September October November December".split(), 1)}
for f in sorted([f for f in glob.glob("*.html")+glob.glob("blog/*.html")+glob.glob("projects/*.html")+glob.glob("work/*.html")
                 if not f.split("/")[-1].startswith("_")]):
	if f == "post-template.html": continue
	m = re.search(r'class="upd">Updated ([A-Z][a-z]+) (\d{4})<', open(f, encoding="utf-8").read())
	if not m:
		print(f"FAIL: {f} carries no 'Updated <month> <year>' in its footer"); bad = 1; continue
	stamps[f] = (m.group(1), m.group(2))
if len(set(stamps.values())) > 1:
	print(f"FAIL: pages disagree about when the site was updated: {sorted(set(stamps.values()))}"); bad = 1
for f, (mon, yr) in stamps.items():
	if mon not in MONTHS:
		print(f"FAIL: {f} names no real month, {mon!r}"); bad = 1; continue
	d = datetime.date(int(yr), MONTHS[mon], 1); today = datetime.date.today()
	if d > datetime.date(today.year, today.month, 1):
		print(f"FAIL: {f} says the site was updated in the future, {mon} {yr}"); bad = 1
	elif (today.year - d.year) * 12 + today.month - d.month > 12:
		print(f"FAIL: {f} still claims {mon} {yr}, which is over a year stale"); bad = 1
sys.exit(bad)
PY

# ------------------------------------ 14. the marker is a promise, not a colour
# From 2026-09-04 the highlighter means one thing: this figure has a receipt,
# and the receipt is one click away. So a highlighted number is a link. The one
# exemption is stated here rather than assumed, and it has a reason: 50,000+ is
# the Brainomania attendance, which no line of the CV carries, so it stays
# unlinked until the press link for that event arrives.
python3 - <<'PY' || fail=1
import re, sys
UNLINKED_ON_PURPOSE = {"50,000+"}
s = open("index.html", encoding="utf-8").read()
bad = 0
for m in re.finditer(r'<span class="hl">([^<]*)</span>', s):
	before = s[:m.start()]
	linked = before.rfind("<a ") > before.rfind("</a>")
	fig = m.group(1)
	if not linked and fig not in UNLINKED_ON_PURPOSE:
		print(f"FAIL: the marker on '{fig}' promises a source and links to none"); bad = 1
	if linked and fig in UNLINKED_ON_PURPOSE:
		print(f"FAIL: '{fig}' is now linked, so take it out of the exemption in rule 14"); bad = 1
sys.exit(bad)
PY

# ------------------------------------- 15. a cited page cannot be allowed to rot
# Every source that points at the open web must also point at a snapshot of it,
# because a link is a promise about something somebody else controls. The essay
# published on 2026-07-27 cites books and journal papers and so links to nothing
# yet, which is why this lane is quiet today; it exists so the first post that
# does cite a web page cannot ship without its archived copy.
python3 - <<'PY' || fail=1
import glob, re, sys
bad = 0
for f in sorted(glob.glob("blog/*.html")):
	if f.endswith("index.html"): continue
	s = open(f, encoding="utf-8").read()
	for li in re.findall(r'(?s)<li id="s\d+">(.*?)</li>', s):
		ext = [u for u in re.findall(r'href="(https?://[^"]+)"', li) if "web.archive.org" not in u]
		if ext and "web.archive.org" not in li:
			print(f"FAIL: {f} cites {ext[0][:60]} with no archived copy beside it"); bad = 1
sys.exit(bad)
PY

# --------------------------- 16. the CV page and the CV PDF cannot drift apart
# They are two renderings of one set of facts and they have disagreed before.
# Every date range printed on the page must appear in the PDF and every date
# range in the PDF must appear on the page, so a role edited in one place and
# not the other fails the build instead of reaching a recruiter.
if command -v pdftotext >/dev/null 2>&1; then
	python3 - <<'PY' || fail=1
import re, subprocess, sys
pdf = subprocess.run(["pdftotext", "-layout", "agosh-baranwal-cv.pdf", "-"],
                     capture_output=True, text=True).stdout
page = open("cv.html", encoding="utf-8").read()
page = re.sub(r"<[^>]+>", " ", page).replace("&ndash;", "-").replace("&middot;", " ")
norm = lambda t: {a + "-" + b for a, b in re.findall(r"(\d{2}/\d{2})\s*[-–]\s*(\d{2}/\d{2})", t)}
cur = lambda t: bool(re.search(r"09/24\s*-?\s*Current", t, re.I))
a, b = norm(page), norm(pdf)
bad = 0
for d in sorted(a - b):
	print(f"FAIL: cv.html shows the dates {d}, which the PDF does not"); bad = 1
for d in sorted(b - a):
	print(f"FAIL: the PDF shows the dates {d}, which cv.html does not"); bad = 1
if cur(page) != cur(pdf):
	print("FAIL: the page and the PDF disagree about whether the MBA is still running"); bad = 1
sys.exit(bad)
PY
else
	echo "SKIP: rule 16 (CV page against CV PDF) needs pdftotext, which is not installed"
fi

[ $fail -eq 0 ] && echo "OK: all invariants hold"
exit $fail
