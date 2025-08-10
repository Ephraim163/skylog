"use client";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";

const tabs = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/timeclock", label: "Time Clock" },
  { href: "/tools", label: "Tools" },
  { href: "/admin", label: "Admin" },
];

export default function Nav() {
  const path = usePathname();
  return (
    <nav className="flex items-center gap-3 p-3 border-b border-[color:var(--border)] bg-[color:var(--bg)]">
      <Link href="/dashboard" className="mr-auto flex items-center gap-2" aria-label="Skylog home">
        <Image src="/skylog-logo.png" alt="Skylog" width={24} height={24} priority />
        <span className="font-extrabold tracking-tight">Skylog</span>
      </Link>
      {tabs.map(t => (
        <Link
          key={t.href}
          className={`px-3 py-1 rounded ${path.startsWith(t.href) ? "bg-[color:var(--chip)]" : "hover:bg-[color:var(--chip)]/40"}`}
          href={t.href}
        >
          {t.label}
        </Link>
      ))}
    </nav>
  );
}
