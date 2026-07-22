import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

for (const page of [
  { path: "/", title: "Echo Cave", marker: "Find your way by listening." },
  { path: "/privacy", title: "Privacy Policy", marker: "Data stored on your iPhone" },
  { path: "/support", title: "Support", marker: "Audio troubleshooting" },
  { path: "/accessibility", title: "Accessibility", marker: "VoiceOver release target" },
]) {
  test(`server-renders ${page.path}`, async () => {
    const response = await render(page.path);
    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
    const html = await response.text();
    assert.match(html, new RegExp(page.title, "i"));
    assert.match(html, new RegExp(page.marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i"));
    assert.match(html, /Skip to main content/);
    assert.match(html, /vidalsulieman@gmail\.com/);
    assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Starter Project/i);
  });
}
