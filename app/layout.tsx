import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Moon Garden — A Tiny Idle Game",
  description: "Gather stardust and grow a peaceful garden beneath the moon.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
