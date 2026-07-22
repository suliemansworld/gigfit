import type { Metadata } from "next";
import { DocumentPage } from "../site-shell";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Echo Cave stores and handles information.",
};

export default function PrivacyPage() {
  return (
    <DocumentPage
      eyebrow="Effective July 22, 2026"
      title="Privacy Policy"
      summary="Echo Cave is designed to be an offline, private game. It has no account, advertising, analytics, or tracking."
    >
      <section>
        <h2>Data stored on your iPhone</h2>
        <p>
          Echo Cave stores game information locally so the game can work and
          remember your progress. This may include:
        </p>
        <ul>
          <li>Game progress, cave state, visited rooms, and move history.</li>
          <li>Inventory, coins, achievements, and journal entries.</li>
          <li>Daily Cave progress and results.</li>
          <li>Audio, haptic, presentation, and accessibility settings.</li>
          <li>Local technical state needed to restore or migrate a save.</li>
        </ul>
        <p>
          This information stays on your iPhone. Echo Cave does not upload it
          to the developer or a server. Deleting the app removes its local data;
          because there is no account or cloud service, the developer cannot
          recover deleted progress.
        </p>
      </section>

      <section>
        <h2>Diagnostics</h2>
        <p>
          Echo Cave can display on-device diagnostics for audio, build,
          storage, or accessibility problems. They remain on your device and
          are not transmitted automatically. If you choose to copy diagnostic
          text and email it to support, the support-email terms below apply.
        </p>
      </section>

      <section>
        <h2>Sharing</h2>
        <p>
          If you choose Share Result for a Daily Cave, Echo Cave passes the text
          you see to the iOS share sheet. You choose the destination or cancel.
          Echo Cave does not receive or store the recipient, destination, or
          result after the share sheet takes over. A service you select handles
          that information under its own privacy policy.
        </p>
      </section>

      <section>
        <h2>Support email</h2>
        <p>
          If you email support, the developer receives what you voluntarily
          include and ordinary email metadata such as your address and message
          time. It is used only to respond, investigate your report, protect
          the app and its users, and meet legal obligations.
        </p>
        <p>
          Support correspondence is retained only as long as reasonably needed
          for those purposes, then deleted or de-identified unless law requires
          longer retention. You may request deletion by emailing{" "}
          <a href="mailto:vidalsulieman@gmail.com">vidalsulieman@gmail.com</a>.
          Do not send passwords, financial information, health information, or
          other sensitive personal data.
        </p>
      </section>

      <section>
        <h2>External services</h2>
        <p>
          Your browser and this website&apos;s host may process standard connection
          information under their own policies. Echo Cave does not append game
          progress or an app-specific identifier to its fixed policy and
          support links. Apple separately handles information when you use the
          App Store, TestFlight, or other Apple services under Apple&apos;s policies.
        </p>
      </section>

      <section>
        <h2>Advertising, analytics, and tracking</h2>
        <p>
          Echo Cave contains no advertising SDK, third-party analytics SDK,
          cross-app tracking, or data broker integration. The developer does
          not sell or rent personal data or use Echo Cave data to track you
          across apps or websites.
        </p>
      </section>

      <section>
        <h2>Children</h2>
        <p>
          Echo Cave is not listed in the Made for Kids category and does not
          knowingly collect personal data from anyone, including children. A
          parent or guardian who believes a child sent personal information in
          a support message may request its deletion.
        </p>
      </section>

      <section>
        <h2>Changes and contact</h2>
        <p>
          If Echo Cave&apos;s data practices change, this policy and the App Store
          disclosures will be updated before the changed version is released.
          Questions, privacy requests, and accessibility concerns can be sent
          to Sulieman Vidal at{" "}
          <a href="mailto:vidalsulieman@gmail.com">vidalsulieman@gmail.com</a>.
        </p>
      </section>
    </DocumentPage>
  );
}
