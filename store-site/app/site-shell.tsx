import Link from "next/link";

const navigation = [
  { href: "/accessibility", label: "Accessibility" },
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
];

export function SiteHeader() {
  return (
    <>
      <a className="skip-link" href="#main-content">
        Skip to main content
      </a>
      <header className="site-header">
        <div className="header-inner">
          <Link className="brand" href="/" aria-label="Echo Cave home">
            <span className="brand-dot" aria-hidden="true" />
            Echo Cave
          </Link>
          <nav className="site-nav" aria-label="Main navigation">
            <ul>
              {navigation.map((item) => (
                <li key={item.href}>
                  <Link href={item.href}>{item.label}</Link>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      </header>
    </>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <span>
          © 2026 Sulieman Vidal ·{" "}
          <a href="mailto:vidalsulieman@gmail.com">vidalsulieman@gmail.com</a>
        </span>
        <div className="footer-links">
          {navigation.map((item) => (
            <Link href={item.href} key={item.href}>
              {item.label}
            </Link>
          ))}
        </div>
      </div>
    </footer>
  );
}

export function DocumentPage({
  eyebrow,
  title,
  summary,
  children,
}: {
  eyebrow: string;
  title: string;
  summary: string;
  children: React.ReactNode;
}) {
  return (
    <div className="site-frame">
      <SiteHeader />
      <main className="document-shell" id="main-content">
        <header className="document-intro">
          <p className="eyebrow">{eyebrow}</p>
          <h1>{title}</h1>
          <p className="document-summary">{summary}</p>
          <p className="last-updated">Last updated July 22, 2026</p>
        </header>
        <div className="document-body">{children}</div>
      </main>
      <SiteFooter />
    </div>
  );
}
