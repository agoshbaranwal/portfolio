#!/bin/bash
# Executable invariants for the portfolio (tvbadger protected-invariants pattern).
# Usage: ./check.sh [new-slug]   — run from the portfolio root after every publish.
cd "$(dirname "$0")"
fail=0

# 1. No <style> tags or inline style attributes inside any post/notebook page.
if grep -l "<style" writing/*.html 2>/dev/null; then
	echo "FAIL: <style> tag found in writing/ (all styling belongs in site.css)"; fail=1
fi
if grep -lE '<[a-z][^>]* style="' writing/*.html 2>/dev/null; then
	echo "FAIL: inline style attribute found in writing/ (add a class to site.css instead)"; fail=1
fi

# 2. No em dashes anywhere in shipped HTML copy.
if grep -l "—" index.html 404.html feed.xml writing/*.html 2>/dev/null; then
	echo "FAIL: em dash found in copy"; fail=1
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

# 6. The locked project order on the homepage: admenow, Utsav, tvbadger.
order=$(grep -oE 'admenow\.vercel|utsav-pi\.vercel|tvbadger\.vercel' index.html | head -3 | tr '\n' ' ')
[ "$order" = "admenow.vercel utsav-pi.vercel tvbadger.vercel " ] || { echo "FAIL: project order changed: $order"; fail=1; }

# 7. The locked section heading.
grep -q ">Things I am building<" index.html || { echo "FAIL: locked heading 'Things I am building' missing"; fail=1; }

[ $fail -eq 0 ] && echo "OK: all invariants hold"
exit $fail
