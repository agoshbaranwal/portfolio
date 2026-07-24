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
if grep -hoE 'href="/[^"]*\.html"' index.html 404.html writing/*.html 2>/dev/null | grep -v feed.xml; then
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

# 6. The locked project order on the homepage: admenow, Utsav, tvbadger.
order=$(sed -n '/>Things I am building</,$p' index.html | grep -oE 'href="https://(admenow|utsav-pi|tvbadger)\.vercel' | sed 's/href="https:\/\///' | head -3 | tr '\n' ' ')
[ "$order" = "admenow.vercel utsav-pi.vercel tvbadger.vercel " ] || { echo "FAIL: project order changed: $order"; fail=1; }

# 7. The locked section heading.
grep -q ">Things I am building<" index.html || { echo "FAIL: locked heading 'Things I am building' missing"; fail=1; }

[ $fail -eq 0 ] && echo "OK: all invariants hold"
exit $fail
