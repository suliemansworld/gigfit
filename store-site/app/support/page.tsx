import type { Metadata } from "next";
import Link from "next/link";
import { DocumentPage } from "../site-shell";

export const metadata: Metadata = {
  title: "Support",
  description: "Help and accessibility support for Echo Cave on iPhone.",
};

export default function SupportPage() {
  return (
    <DocumentPage
      eyebrow="Help when you need it"
      title="Support"
      summary="Get help with navigation, VoiceOver, game audio, saved progress, or accessibility."
    >
      <section>
        <h2>Contact</h2>
        <p>
          For help, bug reports, accessibility feedback, or feature suggestions,
          email{" "}
          <a href="mailto:vidalsulieman@gmail.com">vidalsulieman@gmail.com</a>.
          Support is provided in English. Please do not include passwords,
          financial information, health information, or other sensitive data.
        </p>
      </section>

      <section>
        <h2>Quick start</h2>
        <ol>
          <li>Headphones are recommended for the clearest left and right cues.</li>
          <li>Launch Echo Cave and activate Enter Echo Cave.</li>
          <li>Listen to the introduction and tutorial, then activate Begin.</li>
          <li>Use Listen whenever you want the room and paths described again.</li>
          <li>Use the labeled controls to move forward, retreat, left, or right.</li>
          <li>Use Teleport Home if lost and Repeat Narration if you missed speech.</li>
        </ol>
        <p>
          The first cave is a teaching path. Reach its exit to unlock deeper
          caves with branching passages.
        </p>
      </section>

      <section>
        <h2>VoiceOver</h2>
        <ul>
          <li>Enable VoiceOver with your configured Accessibility Shortcut or in iPhone Settings.</li>
          <li>Use normal VoiceOver navigation, then double-tap to activate a control.</li>
          <li>Optional game gestures are shortcuts; labeled controls and accessibility actions remain available.</li>
          <li>Screen Curtain can remain on during play.</li>
          <li>If speech overlaps, wait for the current message and use Repeat Narration.</li>
        </ul>
        <p>
          Read the <Link href="/accessibility">accessibility statement</Link> for
          supported features, known scope, and testing commitments.
        </p>
      </section>

      <section>
        <h2>Audio troubleshooting</h2>
        <ol>
          <li>Confirm media volume and the intended speaker or headphones.</li>
          <li>In Echo Cave Settings, confirm narration and desired cues are on.</li>
          <li>Pause other audio, return to Echo Cave, and activate Listen.</li>
          <li>Reconnect Bluetooth headphones if iOS changed the audio route.</li>
          <li>Lock and unlock the iPhone, then activate Repeat Narration.</li>
          <li>If the problem continues, relaunch; saved progress should remain.</li>
        </ol>
      </section>

      <section>
        <h2>Resetting or deleting progress</h2>
        <p>
          A reset action changes only the data named in its confirmation. To
          remove all Echo Cave data on an iPhone, use Clear all progress or
          delete the app. With no account or cloud save, deleted progress cannot
          be restored by the developer.
        </p>
      </section>

      <section>
        <h2>What to include in a report</h2>
        <ul>
          <li>Echo Cave version/build, iPhone model, and iOS version.</li>
          <li>VoiceOver, Screen Curtain, Mono Audio, or braille-display state.</li>
          <li>Your audio route and the screen or game action you were using.</li>
          <li>Steps to reproduce, what you expected, and what happened.</li>
          <li>Whether relaunching changed the result or sighted help was required.</li>
        </ul>
      </section>

      <section>
        <h2>Safety</h2>
        <p className="notice">
          Use a comfortable listening volume and stay aware of your
          surroundings. Do not play while driving or whenever game audio could
          prevent you from hearing important environmental sounds.
        </p>
      </section>
    </DocumentPage>
  );
}
