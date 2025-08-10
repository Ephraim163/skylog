import "./globals.css";
import Nav from "@/components/nav";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Nav />
        <main className="p-4 max-w-6xl mx-auto">{children}</main>
      </body>
    </html>
  );
}
