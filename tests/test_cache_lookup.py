#!/usr/bin/env python3
"""Stress test for `_ebay_cache_lookup` in bidrl_arbitrage.py.

Imports the function from the live module, exercises against the live cache,
and runs 10 scenario suites. Cleans up cache mutations on exit.
"""
import importlib.util
import json
import os
import random
import shutil
import sys
import time
import traceback

CACHE_PATH = os.path.expanduser("~/.flipdeals_ebay_cache.json")
BACKUP_PATH = "/tmp/cache.bak"
MOD_PATH = "/home/claude/bidrl_arbitrage.py"

# ── load module without running its main() ────────────────────────────────
spec = importlib.util.spec_from_file_location("bidrl_arbitrage", MOD_PATH)
mod = importlib.util.module_from_spec(spec)
# guard: only execute top-level (module-level argparse runs only under __main__)
spec.loader.exec_module(mod)

lookup = mod._ebay_cache_lookup


def reset_memo():
    """Force the module to reload the cache from disk on the next call."""
    mod._EBAY_CACHE_MEMO = None
    mod._EBAY_CACHE_SEARCH_INDEX = None


# ── results ────────────────────────────────────────────────────────────────
PASS = 0
FAIL = 0
FAILS = []  # (test_name, input, expected, actual)


def check(test_name, inp, expected, actual, *, predicate=None):
    """Record pass/fail. predicate(actual) overrides equality."""
    global PASS, FAIL
    if predicate is not None:
        ok = predicate(actual)
    else:
        ok = actual == expected
    if ok:
        PASS += 1
    else:
        FAIL += 1
        # keep input short for readability
        FAILS.append((test_name, repr(inp)[:80], expected, repr(actual)[:120]))


def is_dict_shape(actual):
    return isinstance(actual, dict) and {
        "avg_sold", "median_sold", "low_sold", "high_sold", "num_sold"
    } <= set(actual.keys())


def is_none(actual):
    return actual is None


# ── backup cache ───────────────────────────────────────────────────────────
shutil.copy(CACHE_PATH, BACKUP_PATH)
print(f"[setup] backed up cache → {BACKUP_PATH}")


try:
    # ══════ Test 1: TYPICAL — should HIT ═══════════════════════════════════
    print("\n=== Test 1: TYPICAL (should HIT) ===")
    typical = [
        ("Apple iPhone 14 Pro Max 256GB Space Black",            "iphone 14"),
        ("DeWalt 20V MAX Cordless Drill Kit with 2 Batteries",   "dewalt 20v max"),
        ("Sony WH-1000XM5 Wireless Headphones",                  "sony wh-1000xm5"),
        ("Apple iPhone 15 128GB Blue Unlocked",                  "iphone 15"),
        ("Apple iPhone 13 Mini 256GB",                           "iphone 13"),
        ("Apple MacBook Pro 16-inch M2 Pro 2023",                "macbook pro"),
        ("Apple MacBook Air 13-inch M2 Midnight",                "macbook air"),
        ("Apple iPad Pro 12.9 6th Gen 256GB WiFi",               "ipad pro"),
        ("Apple iPad Air 5th Generation 64GB",                   "ipad air"),
        ("Apple iPad Mini 6 64GB Cellular",                      "ipad mini"),
        ("PS5 Slim Console Disc Edition Sealed",                 "ps5 slim"),
        ("Microsoft Xbox Series X 1TB Console",                  "xbox series x"),
        ("Nintendo Switch OLED White",                           "switch oled"),
        ("Steam Deck OLED 1TB Limited Edition",                  "steam deck oled"),
        ("Apple Watch Ultra 2 Titanium 49mm",                    "apple watch ultra 2"),
        ("Apple Watch Series 9 GPS 45mm Midnight",               "apple watch series 9"),
        ("Logitech MX Master 3S Wireless Mouse",                 "logitech mx master"),
        ("AirPods Max Space Gray Sealed",                        "airpods max"),
        ("AirPods Pro 2 USB-C MagSafe Case",                     "airpods pro 2"),
        ("NVIDIA RTX 4090 Founders Edition 24GB",                "rtx 4090"),
    ]
    for title, expected_match in typical:
        out = lookup(title)
        check("T1-typical-hit", title, "dict", out, predicate=is_dict_shape)

    # ══════ Test 2: NEGATIVE — should MISS ═════════════════════════════════
    print("\n=== Test 2: NEGATIVE (should MISS) ===")
    negatives = [
        "Random Junk Lot of Office Supplies",
        "Outdoor & Sports Auction",
        "Mystery Box of Returned Items",
        "Box Lot of Assorted Kitchenware",
        "Estate Sale Vintage Items No Description",
        "Auction Section Header Furniture",
        "Used Garden Hose Reel Plastic",
        "Lot of Children's Books Hardcover",
        "Pallet of Returns - Untested",
        "Broken Decorative Ceramic Bowl",
    ]
    for title in negatives:
        out = lookup(title)
        check("T2-negative-miss", title, None, out, predicate=is_none)

    # ══════ Test 3: EDGE CASES ═════════════════════════════════════════════
    print("\n=== Test 3: EDGE CASES ===")
    edges = [
        ("empty",        "",                                   is_none),
        ("none",         None,                                  is_none),
        ("punct-only",   "!!!???",                             is_none),
        ("single-word",  "iPhone",                             is_none),  # 1 token, no fallback
        ("very-long",    "Apple iPhone 14 Pro Max " + ("blah " * 120),  is_dict_shape),
        ("html-entity",  "Apple iPhone &amp; AirPods",         is_dict_shape),  # has 'airpods' but cache has 'airpods max/pro 2', so substring won't match exactly. Token overlap may.
        ("non-ascii",    "Apple™ iPhone® 14 Pro Max",          is_dict_shape),
        ("stopwords",    "the and or for",                     is_none),
    ]
    for name, inp, pred in edges:
        try:
            out = lookup(inp)
        except Exception as e:
            out = f"EXCEPTION: {type(e).__name__}: {e}"
            check(f"T3-{name}", inp, "no exception", out, predicate=lambda a: False)
            continue
        check(f"T3-{name}", inp, pred.__name__, out, predicate=pred)

    # ══════ Test 4: STALE CACHE (TTL respected) ════════════════════════════
    print("\n=== Test 4: STALE CACHE ===")
    with open(CACHE_PATH) as f:
        cache = json.load(f)
    # Pick the entry whose query is "iphone 14"
    target_key = None
    for k, v in cache.items():
        if v.get("query") == "iphone 14":
            target_key = k
            break
    assert target_key, "iphone 14 not in cache?"
    saved_fetched = cache[target_key]["fetched_at"]
    cache[target_key]["fetched_at"] = time.time() - 24 * 3600  # 24h ago, > 12h TTL
    # Also stale-out anything else that might match this title via token overlap
    # (e.g. "iphone 13", "iphone 15", "ipad pro" etc.) so the test isolates iphone 14.
    other_kills = []
    for k, v in cache.items():
        q = v.get("query", "")
        if k == target_key:
            continue
        if "iphone" in q or q in ("ipad pro", "ipad air", "ipad mini"):
            other_kills.append((k, v["fetched_at"]))
            v["fetched_at"] = time.time() - 24 * 3600
    with open(CACHE_PATH, "w") as f:
        json.dump(cache, f)
    reset_memo()
    out = lookup("Apple iPhone 14 Pro Max 256GB")
    check("T4-stale-skip", "iphone 14 stale", None, out, predicate=is_none)

    # restore those entries' fetched_at before continuing
    cache[target_key]["fetched_at"] = saved_fetched
    for k, ts in other_kills:
        cache[k]["fetched_at"] = ts
    with open(CACHE_PATH, "w") as f:
        json.dump(cache, f)
    reset_memo()
    out = lookup("Apple iPhone 14 Pro Max 256GB")
    check("T4-fresh-after-restore", "iphone 14 fresh", "dict", out, predicate=is_dict_shape)

    # ══════ Test 5: MISSING CACHE FILE ═════════════════════════════════════
    print("\n=== Test 5: MISSING CACHE FILE ===")
    shutil.move(CACHE_PATH, CACHE_PATH + ".tmp_hidden")
    reset_memo()
    try:
        out = lookup("Apple iPhone 14 Pro Max")
        check("T5-missing-graceful", "missing-file", None, out, predicate=is_none)
    except Exception as e:
        check("T5-missing-graceful", "missing-file", "no exception",
              f"{type(e).__name__}: {e}", predicate=lambda a: False)
    finally:
        shutil.move(CACHE_PATH + ".tmp_hidden", CACHE_PATH)
        reset_memo()

    # ══════ Test 6: MALFORMED CACHE ════════════════════════════════════════
    print("\n=== Test 6: MALFORMED CACHE ===")
    with open(CACHE_PATH, "w") as f:
        f.write("{not valid json")
    reset_memo()
    try:
        out = lookup("Apple iPhone 14 Pro Max")
        check("T6-malformed-graceful", "bad-json", None, out, predicate=is_none)
    except Exception as e:
        check("T6-malformed-graceful", "bad-json", "no exception",
              f"{type(e).__name__}: {e}", predicate=lambda a: False)
    finally:
        shutil.copy(BACKUP_PATH, CACHE_PATH)
        reset_memo()

    # ══════ Test 7: COLLISION (most-specific wins) ═════════════════════════
    print("\n=== Test 7: COLLISION ===")
    # Cache has "iphone 13", "iphone 14", "iphone 15".
    # We can't directly tell which one was matched from the dict shape, so we
    # peek at the avg_sold to confirm correct entry was returned.
    with open(CACHE_PATH) as f:
        cache = json.load(f)
    by_query = {v["query"]: v for v in cache.values()}

    cases = [
        ("Apple iPhone 14 Pro Max 256GB Space Black", "iphone 14"),
        ("Apple iPhone 15 128GB Blue Unlocked",       "iphone 15"),
        ("Apple iPhone 13 Mini 256GB",                "iphone 13"),
    ]
    for title, expected_query in cases:
        out = lookup(title)
        expected_avg = by_query[expected_query]["avg_sold"]
        actual_avg = (out or {}).get("avg_sold")
        check("T7-collision", title, expected_avg, actual_avg)

    # ══════ Test 8: TOKEN-OVERLAP FALLBACK ═════════════════════════════════
    print("\n=== Test 8: TOKEN-OVERLAP FALLBACK ===")
    # Cache has "macbook pro" and "macbook air".
    # Reordered: "Apple Pro MacBook 16-inch" — "macbook" + "pro" both present
    # but not as substring. Should hit via token overlap (≥2 tokens shared with "macbook pro").
    out = lookup("Apple Pro MacBook 16-inch")
    check("T8-reorder-macbook", "Apple Pro MacBook 16-inch", "dict", out, predicate=is_dict_shape)

    # Cache has "sony wh-1000xm5" — note hyphen. Normalized: "sony wh 1000xm5".
    # Title "Sony Wireless WH-1000XM5 Headphones" — substring works after normalize.
    # Try a reorder that breaks substring: "WH-1000XM5 Sony Premium" → norm "wh 1000xm5 sony premium"
    # Cached norm "sony wh 1000xm5" — substring NO. Tokens: {sony,wh,1000xm5} vs {wh,1000xm5,sony,premium} → overlap=3
    out = lookup("WH-1000XM5 Sony Premium")
    check("T8-reorder-sony", "WH-1000XM5 Sony Premium", "dict", out, predicate=is_dict_shape)

    # Cached "milwaukee m18 fuel" — title "M18 Fuel Milwaukee Drill Set" reordered
    out = lookup("M18 Fuel Milwaukee Drill Set")
    check("T8-reorder-milwaukee", "M18 Fuel Milwaukee Drill Set", "dict", out, predicate=is_dict_shape)

    # ══════ Test 9: STOPWORD-ONLY OVERLAP ══════════════════════════════════
    print("\n=== Test 9: STOPWORD-ONLY OVERLAP ===")
    # If cache had "the new ipad", token overlap with "the and the for" should
    # be empty (all stopwords filtered). Verify with actual stopword-laden input.
    out = lookup("the and the for")
    check("T9-stopwords-only", "the and the for", None, out, predicate=is_none)
    # Also: input has stopwords + 1 real token, overlap with cache should still miss
    out = lookup("the and a for new lot")
    check("T9-stopwords-plus-fillers", "the and a for new lot", None, out, predicate=is_none)

    # ══════ Test 10: PERFORMANCE ═══════════════════════════════════════════
    print("\n=== Test 10: PERFORMANCE ===")
    # Build 1000 synthetic titles — mix of hits and misses, varied length.
    rng = random.Random(42)
    real_brands = ["iphone 14", "macbook pro", "ps5 slim", "rtx 4090",
                   "dewalt 20v", "sony wh-1000xm5", "ipad pro", "airpods max",
                   "garmin fenix 7", "fujifilm x100v"]
    fillers = ["sealed", "open box", "lot of", "untested", "as is", "256gb",
               "good condition", "new in box", "with charger", "no reserve"]
    titles = []
    for i in range(1000):
        if i % 3 == 0:
            # negative
            titles.append(f"Random {rng.choice(['Junk','Box','Lot'])} of {rng.choice(['Items','Goods','Stuff'])} #{i}")
        else:
            b = rng.choice(real_brands)
            f = rng.choice(fillers)
            titles.append(f"{b.title()} {f} item {i}")

    t0 = time.perf_counter()
    per_call = []
    for t in titles:
        s = time.perf_counter()
        lookup(t)
        per_call.append(time.perf_counter() - s)
    total = time.perf_counter() - t0
    avg = (sum(per_call) / len(per_call)) * 1000
    mx = max(per_call) * 1000
    print(f"  total: {total*1000:.1f} ms")
    print(f"  avg:   {avg:.3f} ms/call")
    print(f"  max:   {mx:.3f} ms/call")
    PERF = {"total_ms": total*1000, "avg_ms": avg, "max_ms": mx}
    if avg > 100:
        FAILS.append(("T10-perf-avg", "1000 titles", "<100ms", f"{avg:.1f}ms"))
        FAIL += 1
    else:
        PASS += 1


finally:
    # ── always restore the cache from backup ──────────────────────────────
    shutil.copy(BACKUP_PATH, CACHE_PATH)
    reset_memo()
    print(f"\n[teardown] restored cache from {BACKUP_PATH}")


# ── report ────────────────────────────────────────────────────────────────
print("\n" + "═" * 70)
print(f"RESULTS: {PASS} pass / {FAIL} fail")
print("═" * 70)
if FAILS:
    print("\nFAILURES:")
    for name, inp, exp, act in FAILS:
        print(f"  [{name}]  input={inp}")
        print(f"     expected: {exp}")
        print(f"     actual:   {act}")
print("\nPERF:", PERF if 'PERF' in dir() else "n/a")
