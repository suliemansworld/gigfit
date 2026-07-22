import type { Metadata } from "next";
import { DocumentPage } from "../site-shell";

export const metadata: Metadata = {
  title: "Accessibility",
  description: "Echo Cave accessibility approach, features, and testing commitments.",
};

export default function AccessibilityPage() {
  return (
    <DocumentPage
      eyebrow="Pre-release statement"
      title="Accessibility"
      summary="Echo Cave is an audio-first game created with blind players at its heart—not simply a visual game made readable afterward."
    >
      <section>
        <h2>Our approach</h2>
        <p>
          Sound, speech, touch, and optional haptics are primary ways the cave
          communicates. The version 1 release target is for players to complete
          onboarding, explore, reach an exit, descend, manage items, review the
          journal and achievements, change settings, play a Daily Cave, and
          recover after interruptions without sighted assistance.
        </p>
        <p className="notice">
          This is a pre-release statement. Echo Cave will claim App Store
          VoiceOver support only after its blind-player physical-device test
          gate passes.
        </p>
      </section>

      <section>
        <h2>VoiceOver release target</h2>
        <ul>
          <li>Concise labels, values, traits, and hints for interactive controls.</li>
          <li>Standard focus and activation for movement, Listen, Repeat, Menu, Teleport, inventory, settings, and dialogs.</li>
          <li>Accessible alternatives for every custom swipe, hold, drag, multi-touch, or directional gesture.</li>
          <li>Logical focus order, modal containment, dismissal, and focus restoration.</li>
          <li>Spoken and braille-readable status for changes, discoveries, errors, achievements, and saves.</li>
          <li>Common-task play while Screen Curtain is on.</li>
        </ul>
        <p>
          Optional game gestures are shortcuts, not accessibility requirements.
          When VoiceOver is active, players can use familiar navigation and the
          app&apos;s labeled controls or accessibility actions.
        </p>
      </section>

      <section>
        <h2>Audio and haptics</h2>
        <ul>
          <li>Narration describes the cave, story, discoveries, and game state.</li>
          <li>Directional pings and ambience identify paths and landmarks.</li>
          <li>Listen and Repeat Narration make information available again.</li>
          <li>Haptics are optional and are never the only information channel.</li>
          <li>The release is tested for interruptions, route changes, locking, backgrounding, and headphone disconnection.</li>
        </ul>
        <p>
          Stereo headphones provide the clearest left and right distinction,
          but labeled controls and spoken state are intended to keep tasks
          available without stereo hearing.
        </p>
      </section>

      <section>
        <h2>Visual and braille access</h2>
        <ul>
          <li>Important state is not conveyed by color alone.</li>
          <li>Visible text and controls remain available; audio-only presentation is optional.</li>
          <li>VoiceOver output is available to a paired braille display through iOS.</li>
          <li>The cave-map export uses Unicode braille patterns and Grade 1 English as a supplemental representation.</li>
        </ul>
        <p>
          Larger Text, Sufficient Contrast, Reduced Motion, Voice Control, and
          other App Store accessibility claims will be added only after their
          complete common-task audits pass.
        </p>
      </section>

      <section>
        <h2>Known scope</h2>
        <ul>
          <li>Version 1 supports iPhone only.</li>
          <li>iPad is planned as a separate post-launch evaluation.</li>
          <li>The environmental soundscape is central to play; version 1 does not yet claim captions for every nonverbal sound.</li>
          <li>Accessibility claims apply only to the tested version and device family and are reviewed for every update.</li>
        </ul>
      </section>

      <section>
        <h2>Feedback</h2>
        <p>
          If a task requires sighted assistance, focus becomes trapped, or a
          sound cue lacks an understandable alternative, email{" "}
          <a href="mailto:vidalsulieman@gmail.com">vidalsulieman@gmail.com</a>.
          Include the app version/build, iPhone and iOS version, VoiceOver and
          Screen Curtain state, audio output, what you expected, and what
          happened. Do not include sensitive personal information.
        </p>
      </section>
    </DocumentPage>
  );
}
