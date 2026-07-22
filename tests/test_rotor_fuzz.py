"""Rotor fuzz: simulates the iPhone double-tap-hold-drag-release sequence
that opens and navigates the rotor menu. Catches the bug Sam reported where
the rotor opens but never advances or closes.

Each iteration:
  1. touchstart (tap 1)
  2. touchend
  3. touchstart (tap 2, finger down)
  4. wait HOLD_DURATION + slack -> rotor should open
  5. touchmove down by N * ROTOR_STEP -> rotor index should advance
  6. touchend -> rotor should close, opt.open should fire (or noop on toggle)

Reports any iteration where the rotor failed to open, advance, or close.
"""
import asyncio, sys, random, time, argparse
from playwright.async_api import async_playwright
from test_support import GAME_URL, install_touch_test_helper, launch_browser

HOLD_DURATION = 220  # matches index.html
ROTOR_STEP = 36
DOUBLE_TAP_GAP = 100  # within DOUBLE_TAP_MAX_GAP of 320

DISPATCH = """async (params) => {
  const stage = document.querySelector('.stage') || document.body;
  const rotor = document.getElementById('rotorIndicator');
  const r = stage.getBoundingClientRect();
  const cx = r.left + r.width/2;
  const startY = r.top + r.height/2;
  const initiallyHiddenFromAT = rotor.getAttribute('aria-hidden') === 'true' &&
    rotor.hasAttribute('inert');
  const tap = async (x, y, downMs) => {
    const t = window.echoTestTouch.point(stage, x, y);
    window.echoTestTouch.dispatch(stage, 'touchstart', [t], [t]);
    await new Promise(r => setTimeout(r, downMs));
    window.echoTestTouch.dispatch(stage, 'touchend', [], [t]);
  };

  // Tap 1
  await tap(cx, startY, 30);
  // gap
  await new Promise(r => setTimeout(r, params.gap));
  // Tap 2 - finger goes down and STAYS down
  const t = window.echoTestTouch.point(stage, cx, startY);
  window.echoTestTouch.dispatch(stage, 'touchstart', [t], [t]);
  // Wait for hold timer to fire
  await new Promise(r => setTimeout(r, params.hold));
  const rotorOpened = rotor.classList.contains('show');
  const openToAT = rotor.getAttribute('aria-hidden') === 'false' &&
    !rotor.hasAttribute('inert');

  // Drag down to advance N steps
  let lastIdx = null;
  const advances = [];
  for (let step = 1; step <= params.steps; step++){
    const y = startY + step * params.stepPx;
    const t2 = window.echoTestTouch.point(stage, cx, y);
    window.echoTestTouch.dispatch(stage, 'touchmove', [t2], [t2]);
    await new Promise(r => setTimeout(r, 25));
    const lbl = document.getElementById('rotorLabel')?.textContent;
    const num = document.getElementById('rotorNum')?.textContent;
    advances.push({step, y, lbl, num});
  }

  // Release
  const tEnd = window.echoTestTouch.point(stage, cx, startY + params.steps * params.stepPx);
  window.echoTestTouch.dispatch(stage, 'touchend', [], [tEnd]);
  await new Promise(r => setTimeout(r, 200));
  const rotorClosed = !rotor.classList.contains('show');
  const closedHiddenFromAT = rotor.getAttribute('aria-hidden') === 'true' &&
    rotor.hasAttribute('inert');
  const panelAfter = Array.from(document.querySelectorAll('.panel.show')).map(p => p.id);

  return {
    initiallyHiddenFromAT,
    rotorOpened,
    openToAT,
    advances,
    rotorClosed,
    closedHiddenFromAT,
    panelAfter
  };
}"""

async def run(iterations):
    async with async_playwright() as p:
        b = await launch_browser(p)
        ctx = await b.new_context(viewport={'width':390,'height':844}, has_touch=True, is_mobile=True)
        pg = await ctx.new_page()
        await install_touch_test_helper(pg)
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.on('console', lambda m: errs.append(f"err:{m.text}") if m.type=='error' else None)
        pg.on('dialog', lambda d: asyncio.create_task(d.accept()))
        await pg.goto(GAME_URL, wait_until='networkidle', timeout=20000)
        await pg.wait_for_timeout(800)
        try: await pg.click('#welcomeTap', timeout=2000); await pg.wait_for_timeout(2200)
        except: pass
        try: await pg.click('#introSkip', timeout=2000); await pg.wait_for_timeout(700)
        except: pass
        await pg.click('#tutorialDoneBtn', timeout=30000); await pg.wait_for_timeout(800)

        opens = closes = advanced = 0
        failures = []
        for i in range(iterations):
            params = {
                'gap': random.randint(50, 250),
                'hold': HOLD_DURATION + random.randint(40, 200),
                'steps': random.randint(0, 6),
                'stepPx': random.randint(20, 60),
            }
            try:
                result = await pg.evaluate(DISPATCH, params)
            except Exception as e:
                failures.append({'iter':i, 'err':str(e)[:200]})
                continue
            if not result['initiallyHiddenFromAT']:
                failures.append({'iter':i, 'reason':'closed rotor exposed to assistive technology before opening'})
                continue
            if not result['rotorOpened']:
                failures.append({'iter':i, 'reason':'rotor did not open', 'params':params})
                continue
            if not result['openToAT']:
                failures.append({'iter':i, 'reason':'open rotor hidden from assistive technology', 'params':params})
                continue
            opens += 1
            # Check that index advanced as expected
            if params['steps'] > 0 and params['stepPx'] >= ROTOR_STEP:
                # Should have at least one advance
                last = result['advances'][-1] if result['advances'] else {}
                if last.get('num','').startswith('1 / '):
                    failures.append({'iter':i, 'reason':'rotor opened but did not advance', 'params':params, 'last':last})
                    continue
                advanced += 1
            if not result['rotorClosed']:
                failures.append({'iter':i, 'reason':'rotor stayed open after release', 'params':params})
                continue
            if not result['closedHiddenFromAT']:
                failures.append({'iter':i, 'reason':'closed rotor remained exposed to assistive technology', 'params':params})
                continue
            closes += 1
            # Reset state — close any panel that opened
            await pg.keyboard.press('Escape')
            await pg.wait_for_timeout(120)

        await b.close()

        print()
        print(f"══════════ ROTOR FUZZ — {iterations} iterations ══════════")
        print(f"  opens:    {opens} / {iterations}")
        print(f"  advanced: {advanced} (when steps>0 and stepPx>=ROTOR_STEP)")
        print(f"  closes:   {closes}")
        print(f"  page errors: {len(errs)}")
        for e in errs[:5]:
            print(f"    ERR: {str(e)[:200]}")
        print(f"  failures: {len(failures)}")
        for f in failures[:10]:
            print(f"    {f}")
        return 0 if not failures and not errs else 1

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--iterations', type=int, default=40)
    args = parser.parse_args()
    sys.exit(asyncio.run(run(args.iterations)))
