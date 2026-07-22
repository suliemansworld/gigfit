import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter, SiteHeader } from "./site-shell";

export const metadata: Metadata = {
  title: { absolute: "Echo Cave — Audio-first exploration" },
  description:
    "Official privacy, accessibility, and support information for Echo Cave on iPhone.",
};

const principles = [
  {
    title: "Audio first",
    body: "Narration, directional sound, and optional haptics turn each procedural cave into a place you can understand without seeing it.",
  },
  {
    title: "Private by design",
    body: "There is no account, advertising, analytics, or tracking. Progress and settings stay on your iPhone.",
  },
  {
    title: "Blind players at the heart",
    body: "Standard labeled controls sit alongside optional game gestures, with VoiceOver and Screen Curtain central to release testing.",
  },
];

export default function Home() {
  return (
    <div className="site-frame">
      <SiteHeader />
      <main id="main-content">
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow">An accessible iPhone adventure</p>
            <h1 id="hero-title">Find your way by listening.</h1>
            <p className="hero-lede">
              Echo Cave is an offline, audio-first exploration game created
              with blind players at its heart. Listen for paths, discover what
              the darkness holds, and descend into a cave that changes every
              time.
            </p>
            <div className="button-row" aria-label="Echo Cave information">
              <Link className="button primary" href="/support">
                Get support
              </Link>
              <Link className="button secondary" href="/accessibility">
                Accessibility
              </Link>
            </div>
          </div>
          <div className="echo-mark" aria-hidden="true">
            <span />
            <span />
            <span />
            <span />
          </div>
        </section>

        <section className="principles" aria-labelledby="principles-title">
          <div className="section-heading">
            <p className="eyebrow">What matters here</p>
            <h2 id="principles-title">The cave communicates in more than one way.</h2>
          </div>
          <div className="card-grid">
            {principles.map((principle, index) => (
              <article className="info-card" key={principle.title}>
                <p className="card-index" aria-hidden="true">
                  0{index + 1}
                </p>
                <h3>{principle.title}</h3>
                <p>{principle.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="release-note" aria-labelledby="release-title">
          <div>
            <p className="eyebrow">Version 1</p>
            <h2 id="release-title">Built for iPhone. Tested with care.</h2>
          </div>
          <p>
            Echo Cave is preparing for TestFlight and the App Store. The release
            process includes physical-device VoiceOver testing with blind
            players, offline verification, and audio interruption testing.
          </p>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
