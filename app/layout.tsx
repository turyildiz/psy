import type { Metadata } from "next";
import { Manrope, Bricolage_Grotesque, Caveat, Permanent_Marker } from "next/font/google";
import "./globals.css";

const manrope = Manrope({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-manrope",
});

const caveat = Caveat({
  subsets: ["latin"],
  weight: ["500", "700"],
  variable: "--font-caveat",
});

const permanentMarker = Permanent_Marker({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-marker",
});

const bricolageGrotesque = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700", "800"],
  variable: "--font-bricolage",
});

export const metadata: Metadata = {
  title: "Psy.market — The Psytrance Marketplace",
  description:
    "Buy and sell psytrance fashion, festival clothing, and psychedelic art. The global marketplace for the psytrance community.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${manrope.variable} ${bricolageGrotesque.variable} ${caveat.variable} ${permanentMarker.variable}`}>
      <body>{children}</body>
    </html>
  );
}
