#/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later

set -x

SELF="$0"

PKG="known-false-positives"

die() {
    echo "$SELF: error: $1" >&2
    exit 1
}

DST="`readlink -f "$PWD"`"

REPO="`git rev-parse --show-toplevel`"
test -d "$REPO" || die "not in a git repo"

# get package version from a git tag if available
NV="$(git describe --tags)"
if [[ "$NV" =~ ^$PKG- ]]; then
    VER="${NV#$PKG-}"
else
    # fallback to version 0.0.0 if no version tag is available
    VER="0.0.0-0-g$(git log --pretty="%h" -1)"
fi

TIMESTAMP="`git log --pretty="%cd" --date=iso -1 \
    | tr -d ':-' | tr ' ' . | cut -d. -f 1,2`"

VER="`echo "$VER" | sed "s/-.*-/.$TIMESTAMP./"`"

BRANCH="`git rev-parse --abbrev-ref HEAD`"
test -n "$BRANCH" || die "failed to get current branch name"
test master = "${BRANCH}" || VER="${VER}.${BRANCH//-/_}"
test -z "`git diff HEAD`" || VER="${VER}.dirty"

NV="${PKG}-${VER}"
printf "%s: preparing a release of \033[1;32m%s\033[0m\n" "$SELF" "$NV"

TMP="`mktemp -d`"
trap "rm -rf '$TMP'" EXIT
cd "$TMP" >/dev/null || die "mktemp failed"

# clone the repository
git clone "$REPO" "$PKG"                || die "git clone failed"
cd "$PKG"                               || die "git clone failed"

SRC_TAR="${NV}.tar"
SRC="${SRC_TAR}.xz"
git archive --prefix="$NV/" --format="tar" HEAD -- . > "${TMP}/${SRC_TAR}" \
                                        || die "failed to export sources"
cd "$TMP" >/dev/null                    || die "mktemp failed"
xz -c "$SRC_TAR" > "$SRC"               || die "failed to compress sources"

SPEC="$TMP/$PKG.spec"
cat > "$SPEC" << EOF
Name:       $PKG
Version:    $VER
Release:    1%{?dist}
Summary:    List of known false positives in SAST scanning results

License:    GPLv3+
URL:        https://github.com/openscanhub/known-false-positives
Source:     $SRC

BuildArch:  noarch
Requires:   csmock-common
BuildRequires: csdiff

%description
List of known false positives in SAST scanning results

%prep
%setup -q

%build

# added to expand files to null string if don't exist
shopt -s nullglob

# check for syntax errors, concatenate everything together
csgrep --mode=json */ignore.err */true-positives-ignore.err > known-false-positives-raw.js

# remove duplicates
csgrep --mode=json --remove-duplicates known-false-positives-raw.js \\
    > known-false-positives-dedup.js

# sort by path
cssort --key=path known-false-positives-dedup.js > known-false-positives.js

%install
install -d -m0755 \\
    "\$RPM_BUILD_ROOT"%{_datadir} \\
    "\$RPM_BUILD_ROOT"%{_datadir}/csmock \\
    "\$RPM_BUILD_ROOT"%{_datadir}/csmock/known-false-positives.d

install -v -m0644 known-false-positives.js \\
    "\$RPM_BUILD_ROOT"%{_datadir}/csmock/

for ep in */exclude-paths.txt; do
    install -v -m0644 -D "\$ep" \\
    "\$RPM_BUILD_ROOT"%{_datadir}/csmock/known-false-positives.d/"\$ep"
done

%check
# make process substitution work on el8
set +o posix

# make sure that file names are not mistyped
test -z "\$(find */ -type f | grep -Ev 'ignore.err|true-positives-ignore.err|exclude-paths.txt')"

# make sure that text files are terminated with newline
(set +x
    fail=0
    for i in */*.{err,txt}; do
        diff <(echo) <(tail -c1 \$i) >/dev/null && continue
        echo "text file not terminated with newline: \$i"
        fail=1
    done
    [[ \$fail -eq 0 ]] || exit \$fail
)

# try to compile path-to-exclude regexes to catch at least syntax errors
for ep in */exclude-paths.txt; do
    # process only non-empty lines not starting with #
    grep -Ev '^(#|\$)' \$ep | while read line; do
        csgrep --path "\$line" <&-
    done
done

# print duplicates
csdiff -c known-false-positives-{dedup,raw}.js

# print statistics
csgrep --mode=evtstat known-false-positives.js

%files
%{_datadir}/csmock/known-false-positives.d
%{_datadir}/csmock/known-false-positives.js
EOF

rpmbuild -bb "$SPEC"                            \
    --define "_sourcedir $TMP"                  \
    --define "_specdir $TMP"                    \
    --define "_srcrpmdir $DST"
