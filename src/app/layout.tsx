import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "MyCampus — Your event journey", description: "Every event. Every deadline. One clear plan." };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
