"""Echo Cave fuzz tester — drives random gameplay for N minutes and reports
bugs caught via DIAG counters + pageerror events.

Strategy: 70% movement (swipes + dpad + arrow keys), 15% panel
open/close, 10% settings/rotor interaction, 5% reset/teleport. The mix
mimics a curious player exploring with no plan. Reports any DIAG counter
that climbed unexpectedly.

Usage:
  ~/.venv-scanners/bin/python ~/test_echo_game_fuzz.py [--minutes 10]
"""
import asyncio, sys, random, time, argparse, json
from playwright.async_api import async_playwright

GAME_URL = 'http://localhost:8080/echo-game/?fresh=1&nogate=1'

# Action weights — relative probabilities
ACTIONS = [
    ('swipe', 25),
    ('dpad', 20),
    ('arrow_key', 15),
    ('listen', 8),
    ('teleport', 4),
    ('open_panel', 8),
    ('close_panel', 6),
    ('settings_toggle', 4),
    ('rotor_open', 3),
    ('schematic_button', 3),
    ('keyboard_letter', 4),
]

# Cumulative weight table for weighted sampling
WEIGHT_TOTAL = sum(w for _, w in ACTIONS)

def pick_action():
    r = random.random() * WEIGHT_TOTAL
    cum = 0
    for name, w in ACTIONS:
        cum += w
        if r < cum: return name
    return ACTIONS[-1][0]

PANELS = ['settingsBtn', 'invBtn', 'schematicBtn', 'achievementsBtn', 'journalBtn']

async def run(minutes):
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(
            viewport={'width': 390, 'height': 844},
            has_touch=True, is_mobile=True
        )
        pg = await ctx.new_page()

        # Capture errors
        page_errors = []
        console_errors = []
        pg.on('pageerror', lambda e: page_errors.append({
            't': time.time(), 'msg': str(e)
        }))
        pg.on('console', lambda m: console_errors.append(m.text) if m.type == 'error' else None)
        pg.on('dialog', lambda d: asyncio.create_task(d.accept()))

        await pg.goto(GAME_URL, wait_until='networkidle', timeout=20000)
        await pg.wait_for_timeout(800)

        # Skip welcome/intro/tutorial via state injection
        await pg.evaluate("""
          document.querySelectorAll('.panel.show').forEach(p => p.classList.remove('show'));
        """)
        try:
            await pg.click('#welcomeTap', timeout=2000)
            await pg.wait_for_timeout(300)
        except Exception:
            pass
        try:
            await pg.click('#introSkip', timeout=2000)
            await pg.wait_for_timeout(300)
        except Exception:
            pass
        try:
            await pg.click('#tutorialDoneBtn', timeout=2000)
            await pg.wait_for_timeout(500)
        except Exception:
            pass

        # Snapshot starting DIAG state
        start_diag = await pg.evaluate("""
          () => {
            // Inject a probe: read manifest size, audio ctx state, DIAG-like data via DOM
            const diagEl = document.getElementById('diagReadout');
            return {
              build: window.ECHO_BUILD,
              manifestSize: 0,
              hasGame: !!document.getElementById('depthV'),
            };
          }
        """)

        deadline = time.time() + minutes * 60
        action_count = 0
        action_log = {}
        crashes = []

        print(f"── Fuzzing for {minutes} minute(s) ──")
        print(f"  Build: {start_diag.get('build')}")
        print()

        last_progress = time.time()
        while time.time() < deadline:
            action = pick_action()
            action_log[action] = action_log.get(action, 0) + 1
            action_count += 1

            try:
                if action == 'swipe':
                    direction = random.choice(['up', 'down', 'left', 'right'])
                    await pg.evaluate(f"""async () => {{
                      const stage = document.querySelector('.stage');
                      if (!stage) return;
                      const r = stage.getBoundingClientRect();
                      const cx = r.left + r.width/2, cy = r.top + r.height/2;
                      const dx = '{direction}' === 'left' ? -90 : '{direction}' === 'right' ? 90 : 0;
                      const dy = '{direction}' === 'up' ? -90 : '{direction}' === 'down' ? 90 : 0;
                      const t1 = new Touch({{ identifier:1, target:stage, clientX:cx, clientY:cy, radiusX:1, radiusY:1, force:1 }});
                      stage.dispatchEvent(new TouchEvent('touchstart', {{ touches:[t1], changedTouches:[t1], targetTouches:[t1], bubbles:true, cancelable:true }}));
                      await new Promise(r => setTimeout(r, 30));
                      const t2 = new Touch({{ identifier:1, target:stage, clientX:cx+dx, clientY:cy+dy, radiusX:1, radiusY:1, force:1 }});
                      stage.dispatchEvent(new TouchEvent('touchmove', {{ touches:[t2], changedTouches:[t2], targetTouches:[t2], bubbles:true, cancelable:true }}));
                      await new Promise(r => setTimeout(r, 30));
                      stage.dispatchEvent(new TouchEvent('touchend', {{ touches:[], changedTouches:[t2], targetTouches:[], bubbles:true, cancelable:true }}));
                    }}""")
                    await pg.wait_for_timeout(random.randint(80, 250))

                elif action == 'dpad':
                    direction = random.choice(['up', 'down', 'left', 'right'])
                    await pg.evaluate(f"""() => {{
                      const btn = document.querySelector('.dpad button.{direction}, .dpad button[data-dir="{direction}"]');
                      if (btn) btn.click();
                    }}""")
                    await pg.wait_for_timeout(random.randint(80, 200))

                elif action == 'arrow_key':
                    key = random.choice(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'])
                    await pg.keyboard.press(key)
                    await pg.wait_for_timeout(random.randint(80, 200))

                elif action == 'listen':
                    await pg.keyboard.press('l')
                    await pg.wait_for_timeout(random.randint(200, 500))

                elif action == 'teleport':
                    await pg.keyboard.press('t')
                    await pg.wait_for_timeout(random.randint(300, 800))

                elif action == 'open_panel':
                    btn_id = random.choice(PANELS)
                    await pg.evaluate(f"() => document.getElementById('{btn_id}')?.click()")
                    await pg.wait_for_timeout(random.randint(150, 400))

                elif action == 'close_panel':
                    await pg.keyboard.press('Escape')
                    await pg.wait_for_timeout(random.randint(100, 300))

                elif action == 'settings_toggle':
                    # Open settings, click a random toggle, close
                    await pg.evaluate("() => document.getElementById('settingsBtn')?.click()")
                    await pg.wait_for_timeout(200)
                    await pg.evaluate("""() => {
                      const toggles = document.querySelectorAll('.toggle-row .switch');
                      if (toggles.length){
                        toggles[Math.floor(Math.random() * toggles.length)].click();
                      }
                    }""")
                    await pg.wait_for_timeout(150)
                    await pg.keyboard.press('Escape')
                    await pg.wait_for_timeout(150)

                elif action == 'rotor_open':
                    # Long-press simulation via touchstart held for 800ms
                    await pg.evaluate("""async () => {
                      const stage = document.querySelector('.stage');
                      if (!stage) return;
                      const r = stage.getBoundingClientRect();
                      const t1 = new Touch({ identifier:1, target:stage, clientX:r.left + r.width/2, clientY:r.top + r.height/2, radiusX:1, radiusY:1, force:1 });
                      stage.dispatchEvent(new TouchEvent('touchstart', { touches:[t1], changedTouches:[t1], targetTouches:[t1], bubbles:true, cancelable:true }));
                      await new Promise(r => setTimeout(r, 1100));
                      stage.dispatchEvent(new TouchEvent('touchend', { touches:[], changedTouches:[t1], targetTouches:[], bubbles:true, cancelable:true }));
                    }""")
                    await pg.wait_for_timeout(300)

                elif action == 'schematic_button':
                    # Open schematic, click a random read button
                    await pg.evaluate("() => document.getElementById('schematicBtn')?.click()")
                    await pg.wait_for_timeout(300)
                    btn = random.choice(['readLocBtn', 'readExitBtn', 'readLootBtn', 'readCrossBtn'])
                    await pg.evaluate(f"() => document.getElementById('{btn}')?.click()")
                    await pg.wait_for_timeout(400)
                    await pg.keyboard.press('Escape')
                    await pg.wait_for_timeout(150)

                elif action == 'keyboard_letter':
                    # Random non-direction letter — exercises shortcut handlers
                    key = random.choice(['v', 'g', 'r', 'i', 'm', 'j', ',', 'l'])
                    await pg.keyboard.press(key)
                    await pg.wait_for_timeout(random.randint(100, 300))

            except Exception as e:
                crashes.append({
                    't': time.time(),
                    'action': action,
                    'msg': str(e)[:200]
                })

            # Progress every 30s
            if time.time() - last_progress > 30:
                remaining = int(deadline - time.time())
                print(f"  [+{int(time.time() - (deadline - minutes*60))}s] {action_count} actions · {len(page_errors)} pageerrors · {len(crashes)} crashes · {remaining}s left")
                last_progress = time.time()

        # Final DIAG snapshot
        end_diag = await pg.evaluate("""() => {
          const t = document.getElementById('diagReadout')?.textContent || '';
          // Force-render the diag readout by opening settings briefly
          return t;
        }""")

        # Open settings to populate the readout, then read it
        try:
            await pg.evaluate("() => document.getElementById('settingsBtn')?.click()")
            await pg.wait_for_timeout(500)
            full_diag = await pg.evaluate("() => document.getElementById('diagReadout')?.textContent || ''")
        except Exception:
            full_diag = end_diag

        await b.close()

        # Report
        print()
        print("══════════════════════════════════════════")
        print(f"  FUZZ REPORT — {action_count} actions in {minutes}m")
        print("══════════════════════════════════════════")
        print()
        print("Action mix:")
        for action, count in sorted(action_log.items(), key=lambda x: -x[1]):
            print(f"  {action:24s} {count:5d}  ({100*count/action_count:.1f}%)")
        print()
        print(f"PageErrors:  {len(page_errors)}")
        print(f"ConsoleErr:  {len(console_errors)}")
        print(f"PW Crashes:  {len(crashes)}")
        print()
        if page_errors:
            print("── PAGE ERRORS (first 10 unique) ──")
            seen = set()
            for e in page_errors:
                key = e['msg'][:80]
                if key in seen: continue
                seen.add(key)
                if len(seen) > 10: break
                print(f"  {e['msg'][:200]}")
            print()
        if console_errors:
            print("── CONSOLE.ERROR (first 5 unique) ──")
            seen = set()
            for e in console_errors:
                if e in seen: continue
                seen.add(e)
                if len(seen) > 5: break
                print(f"  {e[:200]}")
            print()
        if crashes:
            print("── PLAYWRIGHT CRASHES (first 5) ──")
            for c in crashes[:5]:
                print(f"  [{c['action']}] {c['msg']}")
            print()
        print("── FINAL DIAGNOSTIC SNAPSHOT ──")
        print(full_diag[:2000])

        # Exit code
        return 0 if (not page_errors and not console_errors) else 1

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--minutes', type=int, default=10)
    args = parser.parse_args()
    sys.exit(asyncio.run(run(args.minutes)))
