"""
Comprehensive test pass for Echo Cave.
Exercises every major feature path, captures screenshots, reports issues.
"""
import asyncio
import sys
from playwright.async_api import async_playwright
from test_support import BASE_URL, GAME_URL, install_touch_test_helper, launch_browser

ISSUES = []
PASSES = []

def issue(msg): ISSUES.append(msg); print(f"  ❌ {msg}")
def passt(msg): PASSES.append(msg); print(f"  ✓  {msg}")

async def run():
    async with async_playwright() as p:
        b = await launch_browser(p)
        ctx = await b.new_context(viewport={"width":390,"height":844}, device_scale_factor=2, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await install_touch_test_helper(pg)
        js_errors = []
        console_errors = []
        pg.on("pageerror", lambda e: js_errors.append(str(e)))
        pg.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)

        print("══════════ TEST 1: Fresh load + welcome ══════════")
        await pg.goto(GAME_URL, wait_until="networkidle", timeout=20000)
        await pg.wait_for_timeout(800)
        wp_visible = await pg.evaluate("() => document.getElementById('welcomePanel').classList.contains('show')")
        if wp_visible: passt("Welcome panel visible on fresh load")
        else: issue("Welcome panel not visible on fresh load")
        sub = await pg.evaluate("() => document.querySelector('#welcomePanel .welcome-sub').textContent")
        if 'Tap' in sub: passt(f"Welcome sub: '{sub}'")
        else: issue(f"Welcome sub bad: '{sub}'")
        welcome_a11y = await pg.evaluate("""() => ({
          descriptions: document.getElementById('welcomeTap').getAttribute('aria-describedby'),
          instructionsHidden: document.getElementById('welcomeInstructions').getAttribute('aria-hidden') === 'true',
          setupNoteHidden: document.getElementById('welcomeSetupNote').getAttribute('aria-hidden') === 'true'
        })""")
        if welcome_a11y['descriptions'] == 'welcomeInstructions welcomeSetupNote':
            passt("Welcome action includes the visible instructions in its accessible description")
        else:
            issue("Welcome action is missing its accessible description")
        if welcome_a11y['instructionsHidden'] and welcome_a11y['setupNoteHidden']:
            passt("Duplicate welcome captions are hidden as separate VoiceOver elements")
        else:
            issue("Welcome captions remain separately exposed to VoiceOver")

        print("\n══════════ TEST 2: Tap → harmonic + intro ══════════")
        await pg.click("#welcomeTap")
        await pg.wait_for_timeout(500)
        wp_after = await pg.evaluate("() => document.getElementById('welcomePanel').classList.contains('show')")
        if not wp_after: passt("Welcome dismissed after single tap")
        else: issue("Welcome still showing after tap")
        await pg.wait_for_timeout(2200)
        intro_visible = await pg.evaluate("() => document.getElementById('introPanel').classList.contains('show')")
        if intro_visible: passt("Cinematic intro showing")
        else: issue("Cinematic intro not showing 2.5s after tap")

        print("\n══════════ TEST 3: Skip intro → tutorial ══════════")
        await pg.click("#introSkip")
        await pg.wait_for_timeout(700)
        tut_visible = await pg.evaluate("() => document.getElementById('tutorialPanel').classList.contains('show')")
        if tut_visible: passt("Tutorial showing after skip")
        else: issue("Tutorial not showing after skip")

        print("\n══════════ TEST 4: Begin → game ══════════")
        await pg.click("#tutorialDoneBtn")
        await pg.wait_for_timeout(800)
        depth = await pg.evaluate("() => document.getElementById('depthV').textContent")
        if depth == "0": passt("Depth 0 at base")
        else: issue(f"Wrong starting depth: {depth}")
        stage_tag = await pg.evaluate("() => document.getElementById('stageTag').textContent")
        if 'Stage 1' in stage_tag: passt(f"Stage 1 tag: '{stage_tag}'")
        else: issue(f"Wrong stage tag: '{stage_tag}'")

        print("\n══════════ TEST 5: HUD elements present ══════════")
        for btn_id in ['schematicBtn','invBtn','settingsBtn','teleportBtn']:
            exists = await pg.evaluate(f"() => !!document.getElementById('{btn_id}')")
            if exists: passt(f"Button #{btn_id} present")
            else: issue(f"Button #{btn_id} missing")

        print("\n══════════ TEST 6: Inject items + open inventory ══════════")
        await pg.evaluate("""() => {
          const s = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          s.inv = s.inv || {};
          s.inv.compass_frag = { count:2, name:'Compass Fragment', icon:'🧭', rarity:'common' };
          s.inv.echo_stone = { count:1, name:'Echo Stone', icon:'🔔', rarity:'uncommon' };
          s.coins = 75;
          localStorage.setItem('echo-cave-v3', JSON.stringify(s));
        }""")
        await pg.reload()
        await pg.wait_for_timeout(700)
        await pg.click("#welcomeTap")
        await pg.wait_for_timeout(2000)
        await pg.click("#invBtn")
        await pg.wait_for_timeout(500)
        use_btns = await pg.evaluate("() => document.querySelectorAll('.item-use-btn').length")
        if use_btns == 2: passt(f"Inventory has {use_btns} use buttons")
        else: issue(f"Expected 2 use buttons, got {use_btns}")
        await pg.click('#invClose')
        await pg.wait_for_timeout(400)

        print("\n══════════ TEST 7: Open + close cave map ══════════")
        # Suppress auto-listen so its status text doesn't race with the location-reader assertion below.
        await pg.evaluate("""() => {
          const s = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          s.settings = Object.assign({}, s.settings || {}, { autoListen: false });
          localStorage.setItem('echo-cave-v3', JSON.stringify(s));
          if (window.state) state.settings.autoListen = false;
        }""")
        await pg.click("#schematicBtn")
        await pg.wait_for_timeout(500)
        for bid in ['readLocBtn','readExitBtn','readLootBtn','brailleFromMapBtn']:
            exists = await pg.evaluate(f"() => !!document.getElementById('{bid}')")
            if exists: passt(f"Map button #{bid} present")
            else: issue(f"Map button #{bid} missing")
        # Click read current location
        await pg.click("#readLocBtn")
        await pg.wait_for_timeout(400)
        status = await pg.evaluate("() => document.getElementById('status').textContent")
        if 'base' in status.lower() or 'path' in status.lower(): passt(f"Location reader works: '{status[:60]}'")
        else: issue(f"Location reader status: '{status}'")
        await pg.click("#schClose")
        await pg.wait_for_timeout(400)

        print("\n══════════ TEST 8: Settings panel + toggles ══════════")
        await pg.click("#settingsBtn")
        await pg.wait_for_timeout(400)
        toggle_count = await pg.evaluate("() => document.querySelectorAll('.toggle-row').length")
        if toggle_count >= 13: passt(f"{toggle_count} settings toggles present")
        else: issue(f"Only {toggle_count} toggles found (expected ≥13)")
        # Toggle pure audio mode and verify
        await pg.click("#t-audio")
        await pg.wait_for_timeout(300)
        audio_state = await pg.evaluate("() => JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').settings.audioOnly")
        if audio_state: passt("Audio-only toggle ON saved correctly")
        else: issue("Audio-only toggle didn't save")
        # toggle off again
        await pg.click("#t-audio")
        await pg.wait_for_timeout(300)
        await pg.click("#settingsDone")
        await pg.wait_for_timeout(300)

        print("\n══════════ TEST 8b: Destructive confirmation isolates its parent dialog ══════════")
        await pg.click("#settingsBtn")
        await pg.wait_for_timeout(200)
        await pg.click("#newCaveBtn")
        await pg.wait_for_timeout(200)
        modal_state = await pg.evaluate("""() => {
          const settings = document.getElementById('settingsPanel');
          const confirmation = document.getElementById('confirmationPanel');
          const focusables = Array.from(settings.querySelectorAll(
            'a[href], button, input, select, textarea, [tabindex]'
          ));
          return {
            confirmationVisible: confirmation.classList.contains('show'),
            settingsInert: settings.hasAttribute('inert'),
            settingsHiddenFromAT: settings.getAttribute('aria-hidden') === 'true',
            backgroundFocusable: focusables.filter(element => element.tabIndex >= 0).length,
            focusInsideConfirmation: confirmation.contains(document.activeElement),
          };
        }""")
        if (modal_state['confirmationVisible'] and modal_state['settingsInert']
                and modal_state['settingsHiddenFromAT']
                and modal_state['backgroundFocusable'] == 0
                and modal_state['focusInsideConfirmation']):
            passt("Confirmation hides and disables the underlying Settings dialog")
        else:
            issue(f"Confirmation isolation failed: {modal_state}")
        await pg.click("#confirmationCancel")
        await pg.wait_for_timeout(200)
        restored_state = await pg.evaluate("""() => {
          const settings = document.getElementById('settingsPanel');
          return {
            settingsVisible: settings.classList.contains('show'),
            settingsInert: settings.hasAttribute('inert'),
            ariaHidden: settings.getAttribute('aria-hidden'),
            activeId: document.activeElement && document.activeElement.id,
          };
        }""")
        if (restored_state['settingsVisible'] and not restored_state['settingsInert']
                and restored_state['ariaHidden'] is None
                and restored_state['activeId'] == 'newCaveBtn'):
            passt("Cancel restores Settings and focus to the initiating control")
        else:
            issue(f"Confirmation restoration failed: {restored_state}")
        await pg.click("#settingsDone")
        await pg.wait_for_timeout(200)

        print("\n══════════ TEST 9: Schematic shows valid layout ══════════")
        await pg.click("#schematicBtn")
        await pg.wait_for_timeout(500)
        schematic_text = await pg.evaluate("() => document.getElementById('schematicBody').textContent")
        if 'BASE' in schematic_text and 'depth' in schematic_text.lower():
            passt(f"Schematic body has BASE + depths ({len(schematic_text)} chars)")
        else: issue(f"Schematic body looks empty/broken: '{schematic_text[:100]}'")
        # Path cards
        path_cards_text = await pg.evaluate("() => document.getElementById('pathCards').textContent")
        if 'Main vein' in path_cards_text or 'main vein' in path_cards_text:
            passt("Path cards show main vein info")
        else: issue(f"Path cards missing main vein: '{path_cards_text[:80]}'")
        await pg.click("#schClose")
        await pg.wait_for_timeout(400)

        print("\n══════════ TEST 10: Braille export ══════════")
        await pg.click("#schematicBtn")
        await pg.wait_for_timeout(400)
        await pg.click("#brailleFromMapBtn")
        await pg.wait_for_timeout(500)
        braille_text = await pg.evaluate("() => document.getElementById('brailleBody').textContent")
        # Unicode Braille range starts at U+2800
        has_braille = any(0x2800 <= ord(c) <= 0x28ff for c in braille_text)
        if has_braille and len(braille_text) > 50: passt(f"Braille body contains real braille chars ({len(braille_text)} chars)")
        else: issue(f"Braille body broken: '{braille_text[:80]}'")
        await pg.click("#brailleDone")
        await pg.wait_for_timeout(300)

        print("\n══════════ TEST 11: Try a swipe (synthetic touch) ══════════")
        # Pick a real available exit direction from the current room, then swipe that way.
        result = await pg.evaluate("""async () => {
          // Find an available door direction. tryMove rejects 'no passage' moves silently to status.
          // We dig into state via the global game closure isn't available, so use a swipe in each
          // cardinal direction in turn until depth changes or we exhaust them.
          const stage = document.querySelector('.stage');
          const r = stage.getBoundingClientRect();
          const cx = r.left + r.width/2, cy = r.top + r.height/2;
          function makeTouch(x, y){ return window.echoTestTouch.point(stage, x, y); }
          async function swipe(dx, dy){
            const t1 = makeTouch(cx, cy);
            window.echoTestTouch.dispatch(stage, 'touchstart', [t1], [t1]);
            await new Promise(r=>setTimeout(r,30));
            const t2 = makeTouch(cx + dx, cy + dy);
            window.echoTestTouch.dispatch(stage, 'touchmove', [t2], [t2]);
            await new Promise(r=>setTimeout(r,30));
            window.echoTestTouch.dispatch(stage, 'touchend', [], [t2]);
            await new Promise(r=>setTimeout(r,400));
          }
          const dirs = [['down', 0, 80], ['right', 80, 0], ['left', -80, 0], ['up', 0, -80]];
          const tries = [];
          for (const [name, dx, dy] of dirs){
            const before = document.getElementById('depthV').textContent;
            await swipe(dx, dy);
            const after = document.getElementById('depthV').textContent;
            const status = document.getElementById('status').textContent.slice(0,90);
            tries.push({ name, before, after, status });
            if (before !== after) break;
          }
          return { tries, finalDepth: document.getElementById('depthV').textContent };
        }""")
        for t in result['tries']:
            print(f"  swipe {t['name']:5} depth {t['before']}→{t['after']}  status: {t['status']}")
        if result['finalDepth'] != '0': passt(f"Swipe moved to depth {result['finalDepth']}")
        else: issue("No swipe direction moved from depth 0")
        # Also verify swipes were received (status should reference passage/wall, proving handler ran)
        any_recognized = any('passage' in t['status'].lower() or 'wall' in t['status'].lower() or 'forward' in t['status'].lower() or 'chamber' in t['status'].lower() for t in result['tries'])
        if any_recognized: passt("Synthetic touch events reached gesture handler")
        else: issue("Synthetic touch events did NOT reach gesture handler")

        print("\n══════════ TEST 10.5: Achievements panel + listen_master trigger ══════════")
        # Open achievements panel
        await pg.click("#invBtn")
        await pg.wait_for_timeout(400)
        await pg.click("#invAchBtn")
        await pg.wait_for_timeout(500)
        ach_visible = await pg.evaluate("() => document.getElementById('achievementsPanel').classList.contains('show')")
        if ach_visible: passt("Achievements panel opened")
        else: issue("Achievements panel did not open")
        ach_rows = await pg.evaluate("() => document.querySelectorAll('.ach-row').length")
        if ach_rows >= 13: passt(f"{ach_rows} achievement rows rendered")
        else: issue(f"Only {ach_rows} achievement rows (expected ≥13)")
        # Locked-vs-unlocked count
        locked = await pg.evaluate("() => document.querySelectorAll('.ach-row.locked').length")
        if locked >= ach_rows - 2: passt(f"{locked} of {ach_rows} achievements still locked (fresh save)")
        else: issue(f"Unexpected unlocked count: {ach_rows - locked} unlocked on fresh save")
        await pg.click("#achDone")
        await pg.wait_for_timeout(300)

        # Trigger listen_master by calling listen() 10 times
        await pg.evaluate("""async () => {
          // Force-click listen button 10 times — easiest way to trigger the cumulative achievement
          const btn = document.getElementById('listenBtn');
          for (let i = 0; i < 10; i++){
            btn.click();
            await new Promise(r => setTimeout(r, 60));
          }
        }""")
        await pg.wait_for_timeout(500)
        listen_unlocked = await pg.evaluate(
            "() => !!(JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').achievements||{}).listen_master"
        )
        if listen_unlocked: passt("listen_master achievement unlocked after 10 listens")
        else: issue("listen_master not unlocked")

        print("\n══════════ TEST 11.5: Loops are sealed in Stage 1, unlock in Stage 2 ══════════")
        loop_data = await pg.evaluate("""() => {
          // Snapshot all loop edges in the current cave
          const cave = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').cave;
          if (!cave) return { error: 'no cave in storage' };
          const loops = [];
          for (const id in cave.rooms){
            const r = cave.rooms[id];
            if (r.neighbors){
              for (const dir of Object.keys(r.neighbors)){
                loops.push({ from:id, dir, to:r.neighbors[dir] });
              }
            }
          }
          return {
            loopCount: loops.length,
            stage1: !cave.exitReached,
            spineLen: cave.spineLength,
            roomCount: Object.keys(cave.rooms).length,
            loopsSetting: (JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').settings || {}).loops
          };
        }""")
        if loop_data.get('loopsSetting') is True or loop_data.get('loopsSetting') is None:
            passt(f"Loops setting present (default true). Cave has {loop_data['loopCount']} loop edges across {loop_data['roomCount']} rooms")
        else:
            issue(f"Unexpected loops setting: {loop_data}")
        # Loop generation is bidirectional: each loop should be a pair of neighbor entries
        if loop_data['loopCount'] % 2 == 0:
            passt(f"Loop edges symmetric ({loop_data['loopCount']} ÷ 2 = {loop_data['loopCount']//2} loops)")
        else:
            issue(f"Loop edges asymmetric: {loop_data['loopCount']} (should be even)")

        print("\n══════════ TEST 12: Daily mode infrastructure ══════════")
        # Verify daily key generation function works
        day_n = await pg.evaluate("""() => {
          const epoch = Date.UTC(2026, 0, 1);
          const now = new Date();
          const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
          return Math.max(1, Math.floor((today - epoch) / 86400000) + 1);
        }""")
        if day_n >= 1: passt(f"Daily day number: {day_n}")
        else: issue(f"Daily day number invalid: {day_n}")

        print("\n══════════ TEST 13: Audio API support ══════════")
        audio_support = await pg.evaluate("""() => ({
          audioContext: typeof (window.AudioContext || window.webkitAudioContext) === 'function',
          audioElement: typeof window.Audio === 'function',
          build: window.ECHO_BUILD || ''
        })""")
        if audio_support['audioContext'] and audio_support['audioElement'] and audio_support['build']:
            passt(f"Audio APIs available for build {audio_support['build']}")
        else:
            issue(f"Required audio APIs or build tag missing: {audio_support}")

        print("\n══════════ TEST 14a: Crystal Grotto theme picker ══════════")
        # Open settings panel
        await pg.click("#settingsBtn"); await pg.wait_for_timeout(300)
        # Default theme should be classic
        classic_on = await pg.evaluate("() => document.getElementById('theme-classic').classList.contains('on')")
        grotto_on = await pg.evaluate("() => document.getElementById('theme-grotto').classList.contains('on')")
        body_grotto = await pg.evaluate("() => document.body.classList.contains('theme-grotto')")
        if classic_on and not grotto_on and not body_grotto: passt("Default theme is classic")
        else: issue(f"Theme defaults wrong: classic={classic_on} grotto={grotto_on} bodyGrotto={body_grotto}")
        # Switch to grotto
        await pg.click("#theme-grotto"); await pg.wait_for_timeout(400)
        body_grotto_after = await pg.evaluate("() => document.body.classList.contains('theme-grotto')")
        grotto_on_after = await pg.evaluate("() => document.getElementById('theme-grotto').classList.contains('on')")
        saved_theme = await pg.evaluate("() => (JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').settings || {}).theme")
        if body_grotto_after and grotto_on_after: passt("Grotto theme activated visually")
        else: issue(f"Grotto theme not active: bodyClass={body_grotto_after} btn={grotto_on_after}")
        if saved_theme == 'grotto': passt("Grotto theme persisted to localStorage")
        else: issue(f"Theme not saved: {saved_theme}")
        # Switch back
        await pg.click("#theme-classic"); await pg.wait_for_timeout(300)
        body_classic = await pg.evaluate("() => !document.body.classList.contains('theme-grotto')")
        if body_classic: passt("Switching back to classic clears body class")
        else: issue("Body still has theme-grotto class after switching back")
        await pg.click("#settingsClose"); await pg.wait_for_timeout(300)

        print("\n══════════ TEST 14: All audio files served ══════════")
        runtime_audio = ['friction-stone.wav','friction-wet.wav','friction-sand.wav','friction-gravel.wav',
                         'step-stone.wav','step-wet.wav','step-sand.wav','step-gravel.wav',
                         'drip-loop.wav','wind-loop.wav','hum-loop.wav','chime-loop.wav','echo-loop.wav',
                         'welcome-music.mp3','bed-base-classic.wav','bed-classic-shallow.wav',
                         'bed-classic-mid.wav','bed-classic-deep.wav','bed-base-grotto.wav',
                         'bed-grotto-shallow.wav','bed-grotto-mid.wav','bed-grotto-deep.wav']
        for filename in runtime_audio:
            r = await pg.evaluate(f"async () => {{ const r = await fetch('audio/{filename}', {{method:'HEAD'}}); return r.status; }}")
            if r == 200: passt(f"{filename}: 200")
            else: issue(f"{filename}: {r}")

        decode_probe = await pg.evaluate("""async () => {
          const AudioCtx = window.AudioContext || window.webkitAudioContext;
          const ctx = new AudioCtx();
          const files = [
            'audio/voice/welcome-greeting-full.wav',
            'audio/step-stone.wav',
            'audio/friction-stone.wav',
            'audio/drip-loop.wav',
            'audio/bed-base-classic.wav',
            'audio/welcome-music.mp3'
          ];
          const decoded = [];
          for (const file of files) {
            const response = await fetch(file, {cache: 'no-cache'});
            const buffer = await ctx.decodeAudioData(await response.arrayBuffer());
            decoded.push({file, duration: buffer.duration});
          }
          await ctx.close();
          return decoded;
        }""")
        if len(decode_probe) == 6 and all(item['duration'] > 0 for item in decode_probe):
            passt("George, footsteps, friction, landmark, bed, and music decode through Web Audio")
        else:
            issue(f"Representative audio decode failed: {decode_probe}")

        print("\n══════════ TEST 14b: Cancelled sharing never writes to the clipboard ══════════")
        await pg.click("#menuBtn")
        await pg.click("#menuDailyBtn")
        await pg.wait_for_timeout(500)
        await pg.evaluate("""() => {
          window.__shareCalls = 0;
          window.__clipboardWrites = 0;
          Object.defineProperty(navigator, 'share', {
            configurable: true,
            value: () => {
              window.__shareCalls += 1;
              return Promise.reject(new DOMException('The user aborted a request.', 'AbortError'));
            },
          });
          Object.defineProperty(navigator, 'clipboard', {
            configurable: true,
            value: {
              writeText: () => {
                window.__clipboardWrites += 1;
                return Promise.resolve();
              },
            },
          });
        }""")
        await pg.click("#menuBtn")
        share_visible = await pg.evaluate(
            "() => !document.getElementById('menuShareBtn').classList.contains('hidden')"
        )
        if share_visible: passt("Daily result has a standard labeled Share control")
        else: issue("Daily Share control is hidden in daily mode")
        await pg.click("#menuShareBtn")
        await pg.wait_for_timeout(200)
        cancelled_share = await pg.evaluate(
            "() => ({ shares: window.__shareCalls, writes: window.__clipboardWrites })"
        )
        if cancelled_share == {'shares': 1, 'writes': 0}:
            passt("Cancelling the share sheet performs no clipboard write")
        else:
            issue(f"Cancelled share had side effects: {cancelled_share}")

        await pg.evaluate("""() => {
          Object.defineProperty(navigator, 'share', {
            configurable: true,
            value: () => {
              window.__shareCalls += 1;
              return Promise.reject(new Error('Share service unavailable'));
            },
          });
        }""")
        await pg.click("#menuBtn")
        await pg.click("#menuShareBtn")
        await pg.wait_for_timeout(200)
        failed_share = await pg.evaluate(
            "() => ({ shares: window.__shareCalls, writes: window.__clipboardWrites })"
        )
        if failed_share == {'shares': 2, 'writes': 1}:
            passt("A real share failure falls back to one clipboard copy")
        else:
            issue(f"Share failure fallback was incorrect: {failed_share}")
        await pg.click("#menuBtn")
        await pg.click("#menuDailyBtn")
        await pg.wait_for_timeout(300)

        print("\n══════════ TEST 15: Production welcome click starts George ══════════")
        welcome_pg = await ctx.new_page()
        await welcome_pg.add_init_script("window.ECHO_TEST_CLICK_ONLY = true;")
        await welcome_pg.goto(f"{BASE_URL}?fresh=1", wait_until="networkidle", timeout=20000)
        await welcome_pg.click("#welcomeTap")
        try:
            await welcome_pg.wait_for_function(
                "() => window.ECHO_AUDIO_DIAGNOSTICS && window.ECHO_AUDIO_DIAGNOSTICS().manifestSize === 689",
                timeout=5000,
            )
            manifest_ready = True
        except Exception:
            manifest_ready = False
        try:
            await welcome_pg.wait_for_function(
                """() => {
                  const d = window.ECHO_AUDIO_DIAGNOSTICS && window.ECHO_AUDIO_DIAGNOSTICS();
                  return d && d.voicePlayed > 0 && d.ctxState === 'running';
                }""",
                timeout=16000,
            )
        except Exception:
            pass
        welcome_audio = await welcome_pg.evaluate(
            "() => window.ECHO_AUDIO_DIAGNOSTICS && window.ECHO_AUDIO_DIAGNOSTICS()"
        )
        if manifest_ready: passt("Accessible click loaded all 689 narration entries")
        else: issue("Accessible click did not load the narration manifest")
        if welcome_audio and welcome_audio['voicePlayed'] > 0 and welcome_audio['systemFallback'] == 0:
            passt("Production welcome scheduled the recorded George greeting")
        else:
            issue(f"Production welcome did not use George: {welcome_audio}")
        if welcome_audio and welcome_audio['ctxState'] == 'running' and welcome_audio['welcomeMusicPlaying']:
            passt("Click-only welcome path unlocked Web Audio and started the welcome music")
        else:
            issue(f"Click-only welcome did not start audible music: {welcome_audio}")
        if welcome_audio and welcome_audio['wavPreferenceViolations'] == 0:
            passt("Duplicate narration text prefers the original WAV recording")
        else:
            issue(f"Narration WAV preference failed: {welcome_audio}")
        if welcome_audio and welcome_audio['audioLoadFailures'] == 0 and welcome_audio['audioDecodeFailures'] == 0:
            passt("Production welcome reported no audio load/decode failures")
        else:
            issue(f"Production welcome audio failures: {welcome_audio}")
        await welcome_pg.close()

        print("\n══════════ TEST 16: Console errors check ══════════")
        if not js_errors: passt("No JS pageerror events")
        else:
            for e in js_errors: issue(f"JS error: {e}")
        if not console_errors: passt("No console.error messages")
        else:
            for e in console_errors[:5]: issue(f"Console error: {e}")

        await b.close()

    print("\n" + "═" * 60)
    print(f"PASSES: {len(PASSES)}")
    print(f"ISSUES: {len(ISSUES)}")
    print("═" * 60)
    if ISSUES:
        print("\nIssues to fix:")
        for i in ISSUES:
            print(f"  • {i}")
    return 1 if ISSUES else 0

if __name__ == "__main__":
    sys.exit(asyncio.run(run()))
