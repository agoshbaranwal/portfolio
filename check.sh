#!/bin/bash
# Executable invariants for the portfolio (tvbadger protected-invariants pattern).
# Usage: ./check.sh [new-slug]   — run from the portfolio root after every publish.
cd "$(dirname "$0")"
fail=0

# 1. No <style> tags or inline style attributes inside any post/notebook page.
if grep -l "<style" writing/*.html 2>/dev/null; then
	echo "FAIL: <style> tag found in writing/ (all styling belongs in site.css)"; fail=1
fi
if grep -lE '<[a-z][^>]* style="' index.html 404.html cv.html writing/*.html 2>/dev/null; then
	echo "FAIL: inline style attribute found (add a class to site.css instead)"; fail=1
fi

# 2. No em dashes anywhere in shipped HTML copy. (cv.html included; the CV keeps
#    its own years-of-experience wording, so it is exempt from the years check.)
if grep -l "—" index.html 404.html cv.html feed.xml post-template.html site.css writing/*.html 2>/dev/null; then
	echo "FAIL: em dash found in copy"; fail=1
fi

# 2b. Exactly the three approved figures, and no percentage stats anywhere.
for fig in "10x ROAS" "\$3M" "\$100k"; do
	n=$(grep -oF "$fig" index.html | wc -l | tr -d ' ')
	[ "$n" = "1" ] || { echo "FAIL: figure '$fig' appears $n times (must be exactly 1)"; fail=1; }
done
if sed 's/href="[^"]*"//g' index.html | grep -oE '[0-9]+%' >/dev/null 2>&1; then
	echo "FAIL: percentage stat found in visible copy (owner ruled: no percentages)"; fail=1
fi

# 3. Never a stated number of years of experience.
if grep -liE "[0-9]+\+? (yrs|years)" index.html 404.html writing/*.html 2>/dev/null; then
	echo "FAIL: years-of-experience figure found"; fail=1
fi

# 4. Internal links must be extensionless (cleanUrls). Feed and external links exempt.
if grep -hoE 'href="/[^"]*\.html"' index.html 404.html cv.html writing/*.html 2>/dev/null | grep -v feed.xml; then
	echo "FAIL: internal link carries .html (breaks cleanUrls style)"; fail=1
fi

# 5. A new slug must appear in all four touched files.
if [ -n "$1" ]; then
	for f in "writing/$1.html" ; do
		[ -f "$f" ] || { echo "FAIL: $f missing"; fail=1; }
	done
	for f in writing/index.html feed.xml index.html; do
		grep -q "$1" "$f" || { echo "FAIL: slug '$1' not referenced in $f"; fail=1; }
	done
fi

# 5b. Every anchor must actually be a link. A swallowed quote (class="x href="/")
#     tokenizes into a styled element with NO href: it looks live and is dead.
#     This shipped once. It never ships again.
python3 - "$PWD" <<'PY' || fail=1
import sys, glob, os
from html.parser import HTMLParser
os.chdir(sys.argv[1])
class P(HTMLParser):
	def __init__(self, f):
		super().__init__(); self.f = f; self.bad = []
	def handle_starttag(self, tag, attrs):
		if tag != "a": return
		d = dict(attrs)
		if not (d.get("href") or "").strip():
			self.bad.append((self.getpos()[0], "no href", attrs))
		for k, _ in attrs:
			if '"' in k or k.endswith("href="):
				self.bad.append((self.getpos()[0], "malformed attribute", attrs))
bad = 0
for f in sorted(glob.glob("*.html") + glob.glob("writing/*.html")):
	p = P(f); p.feed(open(f, encoding="utf-8").read())
	for line, why, attrs in p.bad:
		print(f"FAIL: {f}:{line} anchor {why}: {attrs}"); bad += 1
sys.exit(1 if bad else 0)
PY

# 5c. The location ban: the private city never ships in any public file.
if grep -rliE "barcelona" index.html 404.html cv.html writing/*.html feed.xml sitemap.xml robots.txt 2>/dev/null; then
	echo "FAIL: the banned location appears in shipped copy"; fail=1
fi

# 5d. Every internal link must resolve to a real file (the inverse of rule 4).
python3 - <<'PY' || fail=1
import re, glob, os, sys
bad=0
def target(h):
	h=h.split("#")[0].split("?")[0]
	if not h or not h.startswith("/") or h.startswith("//"): return None
	if h=="/": return "index.html"
	p=h.lstrip("/")
	if os.path.exists(p): return p
	if os.path.exists(p+".html"): return p+".html"
	if os.path.isdir(p) and os.path.exists(p+"/index.html"): return p+"/index.html"
	return "MISSING:"+h
for f in glob.glob("*.html")+glob.glob("writing/*.html"):
	if f=="post-template.html": continue
	for h in re.findall(r'(?:href|src)="([^"]+)"', open(f).read()):
		t=target(h)
		if t and t.startswith("MISSING"):
			print(f"FAIL: {f} links to {h} which resolves to no file"); bad+=1
sys.exit(1 if bad else 0)
PY

# 5e. The bookmark ribbon must point at the newest post in the feed.
rib=$(grep -o 'class="ribbon" href="[^"]*"' index.html | sed 's/.*href="//;s/"//')
new=$(grep -o '<link>https://agoshportfolio.vercel.app/writing/[^<]*</link>' feed.xml | head -1 | sed 's/<link>https:\/\/agoshportfolio.vercel.app//;s/<\/link>//')
[ -n "$rib" ] && [ "$rib" = "$new" ] || { echo "FAIL: ribbon points at '$rib' but the newest feed item is '$new'"; fail=1; }

# 5f. Max two tags per post page.
for f in writing/*.html; do
	[ "$f" = "writing/index.html" ] && continue
	n=$(grep -o 'class="tag"' "$f" | wc -l | tr -d ' ')
	[ "$n" -le 2 ] || { echo "FAIL: $f carries $n tags (max 2)"; fail=1; }
done

# 5g. The deploy fence: private files must be listed in .vercelignore
#     (Vercel ignores .gitignore entirely once a .vercelignore exists).
for pat in ".notes" ".env"; do
	grep -q "$pat" .vercelignore || { echo "FAIL: .vercelignore does not fence $pat"; fail=1; }
done

# 5h. The freshness marker may not stand on stale ink: if the notebook says a
#     note is still drying, the newest feed item must be under 45 days old.
if grep -q 'class="fresh"' writing/index.html 2>/dev/null; then
	python3 - <<'PY' || { echo "FAIL: 'still drying' but the newest post is over 45 days old (remove the span.fresh)"; fail=1; }
import re, sys
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone
t=open("feed.xml").read()
d=re.search(r"<pubDate>([^<]+)</pubDate>", t)
sys.exit(0 if d and (datetime.now(timezone.utc)-parsedate_to_datetime(d.group(1))).days<=45 else 1)
PY
fi

# 6. The locked project order on the homepage: admenow, Utsav, tvbadger, On Record.
order=$(sed -n '/id="building-h">Projects</,$p' index.html | grep -oE 'href="https://(admenow\.vercel|utsav-pi\.vercel|tvbadger\.vercel|agoshbaranwal\.github)' | sed 's/href="https:\/\///' | head -4 | tr '\n' ' ')
[ "$order" = "admenow.vercel utsav-pi.vercel tvbadger.vercel agoshbaranwal.github " ] || { echo "FAIL: project order changed: $order"; fail=1; }

# 7. The locked section headings must match their nav labels (owner rule
#    2026-08-15: every label says plainly what is behind it).
grep -q 'id="building-h">Projects<' index.html || { echo "FAIL: the projects heading must read 'Projects' (matches the nav)"; fail=1; }
grep -q 'id="notebook-h">Latest posts<' index.html || { echo "FAIL: the homepage blog teaser must read 'Latest posts'"; fail=1; }
grep -q '<a href="/writing">Blogs</a>' index.html || { echo "FAIL: nav 'Blogs' must point at /writing, not a homepage anchor"; fail=1; }

# 7b. Banned interface words: the aphoristic voice may not return to the UI.
if grep -rniE "late show|the notebook|still drying|still on the bench|pass it on|what is in here|the short version|where this comes from|the full r|written with one pen|the front page|the rest of the notebook" index.html 404.html cv.html writing/*.html 2>/dev/null; then
	echo "FAIL: a non-standard interface label is back (see the 2026-08-15 copy rule)"; fail=1
fi

[ $fail -eq 0 ] && echo "OK: all invariants hold"
exit $fail
