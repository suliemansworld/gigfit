import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ??
    requestHeaders.get("host") ??
    "localhost:3000";
  const protocol =
    requestHeaders.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const metadataBase = new URL(`${protocol}://${host}`);

  return {
    metadataBase,
    title: {
      default: "Echo Cave",
      template: "%s — Echo Cave",
    },
    description:
      "Official privacy, accessibility, and support information for Echo Cave on iPhone.",
    openGraph: {
      type: "website",
      title: "Echo Cave",
      description: "Find your way by listening.",
      images: [
        {
          url: new URL("/og.jpg", metadataBase),
          width: 1200,
          height: 630,
          alt: "Echo Cave — Find your way by listening.",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Echo Cave",
      description: "Find your way by listening.",
      images: [new URL("/og.jpg", metadataBase)],
    },
  };
}

export const viewport: Viewport = {
  colorScheme: "dark",
  themeColor: "#090b10",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
