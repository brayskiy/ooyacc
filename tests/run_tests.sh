#!/usr/bin/env bash
#
# ooyacc test harness.
#
# For every grammar in tests/cases/<name>.y:
#   1. generate a parser with ooyacc (-d, so %union becomes YYSTYPE)
#   2. compile the generated parser together with the generic driver
#   3. run it on <name>.in and diff stdout against <name>.expected
#
# Exit status is non-zero if any case fails.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOYACC="$ROOT/bin/ooyacc"
TESTS="$ROOT/tests"
CASES="$TESTS/cases"
DRIVER="$TESTS/driver.cpp"
BUILD="$TESTS/build"
CXX="${CXX:-g++}"
CXXFLAGS="${CXXFLAGS:--std=c++17 -O2}"

if [ ! -x "$OOYACC" ]; then
    echo "Building ooyacc ..."
    make -C "$ROOT" directories program >/dev/null || { echo "ooyacc build failed"; exit 1; }
fi

mkdir -p "$BUILD"
pass=0
fail=0
failed=()

for gram in "$CASES"/*.y; do
    name="$(basename "$gram" .y)"
    wd="$BUILD/$name"
    rm -rf "$wd"; mkdir -p "$wd"
    cp "$gram" "$wd/$name.y"

    if ! ( cd "$wd" && "$OOYACC" -d "$name.y" ) 2> "$wd/gen.log"; then
        echo "[GEN FAIL]     $name"; sed 's/^/    /' "$wd/gen.log"
        fail=$((fail+1)); failed+=("$name"); continue
    fi

    if ! "$CXX" $CXXFLAGS -I "$wd" "$wd/y.tab.cpp" "$DRIVER" -o "$wd/run" 2> "$wd/compile.log"; then
        echo "[COMPILE FAIL] $name"; sed 's/^/    /' "$wd/compile.log"
        fail=$((fail+1)); failed+=("$name"); continue
    fi

    "$wd/run" < "$CASES/$name.in" > "$wd/actual.txt" 2> "$wd/stderr.txt"

    if diff -u "$CASES/$name.expected" "$wd/actual.txt" > "$wd/diff.txt"; then
        echo "[PASS]         $name"
        pass=$((pass+1))
    else
        echo "[FAIL]         $name"; sed 's/^/    /' "$wd/diff.txt"
        fail=$((fail+1)); failed+=("$name")
    fi
done

echo "--------------------------------------------------"
echo "Passed: $pass   Failed: $fail"
if [ "$fail" -ne 0 ]; then
    echo "Failing: ${failed[*]}"
    exit 1
fi
