"""End-to-end gameplay test: walk to exit, traverse loop, verify achievements."""
import asyncio
import sys
from playwright.async_api import async_playwright
from test_support import GAME_URL, launch_browser

PASSES = []
ISSUES = []
def passt(m): PASSES.append(m); print(f"  ✓  {m}")
def issue(m): ISSUES.append(m); print(f"  ❌ {m}")

async def run():
    async with async_playwright() as p:
        b = await launch_browser(p)
        ctx = await b.new_context(viewport={"width":390,"height":844}, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        errs = []
        pg.on("pageerror", lambda e: errs.append(("pageerror", str(e))))
        pg.on("console", lambda m: errs.append(("console.error", m.text)) if m.type == "error" else None)

        # Keep a compatibility handler for any browser-native dialog regression.
        pg.on("dialog", lambda d: asyncio.create_task(d.accept()))
        await pg.goto(GAME_URL, wait_until="networkidle", timeout=20000)
        await pg.wait_for_timeout(800)
        await pg.click("#welcomeTap"); await pg.wait_for_timeout(2200)
        await pg.click("#introSkip"); await pg.wait_for_timeout(700)
        await pg.click("#tutorialDoneBtn"); await pg.wait_for_timeout(800)

        print("══════════ E2E 1: Walk spine to exit ══════════")
        walk = await pg.evaluate("""async () => {
          const cave = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').cave;
          const exitId = cave.exitId;
          const stage = document.querySelector('.stage');
          const r = stage.getBoundingClientRect();
          const cx = r.left + r.width/2, cy = r.top + r.height/2;
          function makeTouch(x, y){ return new Touch({ identifier:1, target:stage, clientX:x, clientY:y, radiusX:1, radiusY:1, force:1 }); }
          const SWIPE = { up:[0,-90], down:[0,90], left:[-90,0], right:[90,0] };
          async function swipe(dir){
            const [dx, dy] = SWIPE[dir];
            const t1 = makeTouch(cx, cy);
            stage.dispatchEvent(new TouchEvent('touchstart', { touches:[t1], changedTouches:[t1], targetTouches:[t1], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,30));
            const t2 = makeTouch(cx+dx, cy+dy);
            stage.dispatchEvent(new TouchEvent('touchmove', { touches:[t2], changedTouches:[t2], targetTouches:[t2], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,30));
            stage.dispatchEvent(new TouchEvent('touchend', { touches:[], changedTouches:[t2], targetTouches:[], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,400));
          }
          let currentId = cave.rootId;
          for (let step = 0; step < 14; step++){
            const cur = cave.rooms[currentId];
            if (cur.id === exitId) break;
            let chosen = null;
            for (const dir of Object.keys(cur.children)){
              const child = cave.rooms[cur.children[dir]];
              if (child.onSpine){ chosen = { dir, childId: cur.children[dir] }; break; }
            }
            if (!chosen) break;
            await swipe(chosen.dir);
            currentId = chosen.childId;
          }
          await new Promise(r=>setTimeout(r, 2500));  // wait for fanfare + achievement chimes
          const after = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          return {
            exitReached: !!after.exitReached,
            stageTag: document.getElementById('stageTag').textContent,
            depth: document.getElementById('depthV').textContent,
            achievements: Object.keys(after.achievements || {}),
            spineLen: cave.spineLength,
            visitedRooms: Object.keys(after.visited || {}).length,
            totalRooms: Object.keys(cave.rooms).length
          };
        }""")
        print(f"  result: {walk}")
        if walk['exitReached']: passt("Exit reached, Stage 2 unlocked")
        else: issue(f"Exit not reached. depth={walk['depth']}")
        if 'Stage 2' in walk['stageTag']: passt(f"Stage tag updated: {walk['stageTag']}")
        else: issue(f"Stage tag not updated: {walk['stageTag']}")
        if 'first_step' in walk['achievements']: passt("first_step achievement earned")
        else: issue("first_step not awarded after walking")
        if 'exit_found' in walk['achievements']: passt("exit_found achievement earned")
        else: issue("exit_found not awarded")

        print("\n══════════ E2E 2: Open achievements panel after exit ══════════")
        await pg.click("#invBtn"); await pg.wait_for_timeout(400)
        await pg.click("#invAchBtn"); await pg.wait_for_timeout(500)
        unlocked = await pg.evaluate("() => document.querySelectorAll('.ach-row:not(.locked)').length")
        if unlocked >= 2: passt(f"{unlocked} achievements visibly unlocked in panel")
        else: issue(f"Only {unlocked} unlocked rows showing")
        await pg.click("#achDone"); await pg.wait_for_timeout(300)

        print("\n══════════ E2E 3: Branches reachable in Stage 2 ══════════")
        # Pick a non-spine room and walk there
        branch_walk = await pg.evaluate("""async () => {
          const cave = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').cave;
          // Find a non-spine, non-leaf branch room
          const branchRooms = Object.values(cave.rooms).filter(r => !r.onSpine && !r.isExit);
          if (branchRooms.length === 0) return { skipped: 'no branch rooms' };
          const target = branchRooms[0];
          // Build path from base to target via parentId chain
          const path = [];
          let r = target;
          while (r && r.parentId){
            const parent = cave.rooms[r.parentId];
            for (const dir of Object.keys(parent.children)){
              if (parent.children[dir] === r.id){ path.unshift(dir); break; }
            }
            r = parent;
          }
          // Teleport home first
          document.getElementById('teleportBtn').click();
          await new Promise(r=>setTimeout(r,700));
          const stage = document.querySelector('.stage');
          const rr = stage.getBoundingClientRect();
          const cx = rr.left + rr.width/2, cy = rr.top + rr.height/2;
          function makeTouch(x, y){ return new Touch({ identifier:1, target:stage, clientX:x, clientY:y, radiusX:1, radiusY:1, force:1 }); }
          const SWIPE = { up:[0,-90], down:[0,90], left:[-90,0], right:[90,0] };
          async function swipe(dir){
            const [dx, dy] = SWIPE[dir];
            const t1 = makeTouch(cx, cy);
            stage.dispatchEvent(new TouchEvent('touchstart', { touches:[t1], changedTouches:[t1], targetTouches:[t1], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,25));
            const t2 = makeTouch(cx+dx, cy+dy);
            stage.dispatchEvent(new TouchEvent('touchmove', { touches:[t2], changedTouches:[t2], targetTouches:[t2], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,25));
            stage.dispatchEvent(new TouchEvent('touchend', { touches:[], changedTouches:[t2], targetTouches:[], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,350));
          }
          for (const dir of path){ await swipe(dir); }
          await new Promise(r=>setTimeout(r,400));
          const after = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          return {
            targetId: target.id,
            targetDepth: target.depth,
            pathLen: path.length,
            currentMatchesTarget: after.currentId === target.id,
            currentId: after.currentId,
            statusText: document.getElementById('status').textContent.slice(0,90)
          };
        }""")
        print(f"  result: {branch_walk}")
        if branch_walk.get('skipped'):
            passt(f"Skipped (no branch rooms in this seed): {branch_walk['skipped']}")
        elif branch_walk.get('currentMatchesTarget'):
            passt(f"Reached branch room {branch_walk['targetId']} at depth {branch_walk['targetDepth']}")
        else:
            issue(f"Could not reach branch room. landed at {branch_walk.get('currentId')} (target {branch_walk.get('targetId')})")

        print("\n══════════ E2E 4: Loop traversal triggers crossover_found ══════════")
        loop_test = await pg.evaluate("""async () => {
          const cave = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').cave;
          let loopRoom = null;
          for (const id in cave.rooms){
            const r = cave.rooms[id];
            if (r.neighbors && Object.keys(r.neighbors).length){ loopRoom = r; break; }
          }
          if (!loopRoom) return { skipped: 'no loop in this seed' };
          const path = [];
          let r = loopRoom;
          while (r && r.parentId){
            const parent = cave.rooms[r.parentId];
            for (const dir of Object.keys(parent.children)){
              if (parent.children[dir] === r.id){ path.unshift(dir); break; }
            }
            r = parent;
          }
          document.getElementById('teleportBtn').click();
          await new Promise(r=>setTimeout(r,700));
          const stage = document.querySelector('.stage');
          const rr = stage.getBoundingClientRect();
          const cx = rr.left + rr.width/2, cy = rr.top + rr.height/2;
          function makeTouch(x, y){ return new Touch({ identifier:1, target:stage, clientX:x, clientY:y, radiusX:1, radiusY:1, force:1 }); }
          const SWIPE = { up:[0,-90], down:[0,90], left:[-90,0], right:[90,0] };
          async function swipe(dir){
            const [dx, dy] = SWIPE[dir];
            const t1 = makeTouch(cx, cy);
            stage.dispatchEvent(new TouchEvent('touchstart', { touches:[t1], changedTouches:[t1], targetTouches:[t1], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,25));
            const t2 = makeTouch(cx+dx, cy+dy);
            stage.dispatchEvent(new TouchEvent('touchmove', { touches:[t2], changedTouches:[t2], targetTouches:[t2], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,25));
            stage.dispatchEvent(new TouchEvent('touchend', { touches:[], changedTouches:[t2], targetTouches:[], bubbles:true, cancelable:true }));
            await new Promise(r=>setTimeout(r,350));
          }
          for (const dir of path){ await swipe(dir); }
          const beforeAch = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}').achievements || {};
          const loopDir = Object.keys(loopRoom.neighbors)[0];
          await swipe(loopDir);
          await new Promise(r=>setTimeout(r,1500));  // wait for unlock
          const after = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          return {
            loopRoomId: loopRoom.id,
            loopDir,
            knownLoops: Object.keys(after.knownLoops || {}).length,
            crossoverAchieved: !!(after.achievements || {}).crossover_found,
            crossoverWasAchievedBefore: !!beforeAch.crossover_found
          };
        }""")
        print(f"  result: {loop_test}")
        if loop_test.get('skipped'):
            passt(f"Skipped: {loop_test['skipped']}")
        elif loop_test.get('crossoverAchieved'):
            passt("crossover_found achievement earned via loop traversal")
        else:
            issue(f"crossover_found NOT awarded after loop. knownLoops={loop_test.get('knownLoops')}")

        print("\n══════════ E2E 4b: Journal entries logged from achievements ══════════")
        # By now first_step + exit_found + (maybe) crossover_found have unlocked.
        # The journal is wired off unlock(), with a 1.4s delay to let toasts clear.
        await pg.wait_for_timeout(1800)
        journal_state = await pg.evaluate("""() => {
          const s = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          return {
            entries: (s.journal || []).map(e => e.id),
            seen: Object.keys(s.journalSeen || {}),
            badgeText: document.getElementById('journalBadge').textContent,
            badgeHidden: document.getElementById('journalBadge').classList.contains('hidden'),
          };
        }""")
        print(f"  result: {journal_state}")
        if 'first_step' in journal_state['entries'] and 'exit_found' in journal_state['entries']:
            passt(f"Journal logged first_step + exit_found ({len(journal_state['entries'])} total entries)")
        else:
            issue(f"Journal missing core entries. got: {journal_state['entries']}")
        if not journal_state['badgeHidden'] and int(journal_state['badgeText']) == len(journal_state['entries']):
            passt(f"Journal badge shows {journal_state['badgeText']}")
        else:
            issue(f"Journal badge wrong: text={journal_state['badgeText']} hidden={journal_state['badgeHidden']}")
        # Open journal and verify it renders
        await pg.click("#journalBtn"); await pg.wait_for_timeout(400)
        rendered = await pg.evaluate("() => document.querySelectorAll('#journalList .journal-row').length")
        if rendered == len(journal_state['entries']):
            passt(f"Journal panel rendered {rendered} entries")
        else:
            issue(f"Journal render mismatch: rendered={rendered}, state={len(journal_state['entries'])}")
        await pg.click("#journalDone"); await pg.wait_for_timeout(300)

        print("\n══════════ E2E 4c: SVG schematic renders nodes + edges ══════════")
        await pg.click("#schematicBtn"); await pg.wait_for_timeout(500)
        svg_state = await pg.evaluate("""() => {
          const svg = document.querySelector('#schematicSvgWrap svg');
          if (!svg) return { hasSvg: false };
          return {
            hasSvg: true,
            nodes: svg.querySelectorAll('circle.node').length,
            edges: svg.querySelectorAll('line.edge, path.edge').length,
            youNode: !!svg.querySelector('circle.node.you'),
            exitNode: !!svg.querySelector('circle.node.exit'),
            baseNode: !!svg.querySelector('circle.node.base'),
          };
        }""")
        print(f"  result: {svg_state}")
        if svg_state.get('hasSvg') and svg_state.get('nodes', 0) >= 5:
            passt(f"SVG schematic rendered {svg_state['nodes']} nodes / {svg_state['edges']} edges")
        else:
            issue(f"SVG schematic missing or sparse: {svg_state}")
        if svg_state.get('youNode') and svg_state.get('baseNode'):
            passt("SVG includes YOU + BASE markers")
        else:
            issue(f"SVG missing key nodes: {svg_state}")
        await pg.click("#schClose"); await pg.wait_for_timeout(300)

        print("\n══════════ E2E 4d: Descent button visible after exit ══════════")
        descend_visible = await pg.evaluate("() => !document.getElementById('descendBtn').classList.contains('hidden')")
        if descend_visible: passt("Descend button visible after exit reached")
        else: issue("Descend button still hidden after exit reached")
        # Descend
        before_level = await pg.evaluate("() => (JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').level)||1")
        before_spine = await pg.evaluate("() => JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').cave.spineLength")
        await pg.click("#descendBtn")
        await pg.click("#confirmationAccept")
        await pg.wait_for_timeout(900)
        after = await pg.evaluate("""() => {
          const s = JSON.parse(localStorage.getItem('echo-cave-v3') || '{}');
          return {
            level: s.level,
            depth: document.getElementById('depthV').textContent,
            spineLen: s.cave.spineLength,
            exitReached: !!s.exitReached,
            stageTag: document.getElementById('stageTag').textContent,
            descendHidden: document.getElementById('descendBtn').classList.contains('hidden'),
            journalEmpty: (s.journal || []).length === 0,
          };
        }""")
        print(f"  result: {after}")
        if after['level'] == before_level + 1: passt(f"Level incremented {before_level} → {after['level']}")
        else: issue(f"Level didn't bump: before={before_level} after={after['level']}")
        if after['spineLen'] > before_spine: passt(f"Spine grew {before_spine} → {after['spineLen']} on level {after['level']}")
        else: issue(f"Spine didn't grow on descent: {before_spine} → {after['spineLen']}")
        if after['depth'] == '0': passt("Depth reset to 0 in new level")
        else: issue(f"Depth wrong after descent: {after['depth']}")
        if not after['exitReached']: passt("Exit unreached in new level (back to Stage 1)")
        else: issue("exitReached not cleared on descent")
        if after['descendHidden']: passt("Descend button hidden again on new level")
        else: issue("Descend button still visible on new level")
        # Journal is now a continuous career record across descents.
        # On descent we expect ONE new bridge entry to have been recorded
        # in addition to any prior entries.
        journal_after_descend = await pg.evaluate("() => (JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').journal||[])")
        last_entry = journal_after_descend[-1] if journal_after_descend else None
        if last_entry and last_entry.get('id', '').startswith('descent_to_level_'):
            passt(f"Descent bridge journal entry recorded: {last_entry['id']}")
        else:
            issue(f"Descent bridge entry missing. last entry: {last_entry}")
        if f"Level {after['level']}" in after['stageTag']: passt(f"Stage tag shows new level: '{after['stageTag']}'")
        else: issue(f"Stage tag missing level: '{after['stageTag']}'")

        print("\n══════════ E2E 5: Reset cave preserves achievements ══════════")
        # Achievements are global to the player, NOT per-cave. Reset cave should keep them.
        await pg.click("#settingsBtn"); await pg.wait_for_timeout(400)
        before_ach = await pg.evaluate("() => Object.keys((JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').achievements)||{}).length")
        await pg.click("#newCaveBtn")
        await pg.click("#confirmationAccept")
        await pg.wait_for_timeout(800)
        after_ach = await pg.evaluate("() => Object.keys((JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').achievements)||{}).length")
        depth_after = await pg.evaluate("() => document.getElementById('depthV').textContent")
        if after_ach == before_ach: passt(f"Achievements preserved across reset cave ({after_ach})")
        else: issue(f"Achievements changed on reset: {before_ach} → {after_ach}")
        if depth_after == "0": passt("Depth back to 0 after reset (new cave)")
        else: issue(f"Depth not reset: {depth_after}")
        # Journal IS per-cave, so it should be cleared on reset.
        journal_after_reset = await pg.evaluate("() => (JSON.parse(localStorage.getItem('echo-cave-v3')||'{}').journal||[]).length")
        if journal_after_reset == 0: passt("Journal cleared on reset cave (per-cave lore)")
        else: issue(f"Journal not cleared on reset: {journal_after_reset} entries remain")

        print("\n══════════ E2E 6: No JS errors during entire run ══════════")
        if not errs: passt("No JS / console.error during full e2e gameplay")
        else:
            for kind, msg in errs[:8]: issue(f"{kind}: {msg}")

        await b.close()

    print("\n" + "═" * 60)
    print(f"PASSES: {len(PASSES)}")
    print(f"ISSUES: {len(ISSUES)}")
    print("═" * 60)
    if ISSUES:
        print("\nIssues:")
        for i in ISSUES: print(f"  • {i}")
    return 1 if ISSUES else 0

if __name__ == "__main__":
    sys.exit(asyncio.run(run()))
