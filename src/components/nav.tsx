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
  // `usePathname` may return `null` during initial render in some environments
  // which would cause `startsWith` to throw. Default to empty string so the
  // navigation bar renders safely even when the path is temporarily unknown.
  const path = usePathname() ?? "";
  return (
    <nav className="flex items-center justify-between px-4 py-3 border-b border-[color:var(--border)]">
      <Link href="/dashboard" className="flex items-center gap-2">
        <Image src="/skylog-logo.png" alt="Skylog" width={20} height={20} />
        <span className="font-bold">Skylog</span>
      </Link>

      <ul className="flex items-center gap-4">
        {tabs.map(t => (
          <li key={t.href}>
            <Link
              href={t.href}
              className={`px-3 py-1 rounded ${
                path.startsWith(t.href)
                  ? "bg-[color:var(--chip)]"
                  : "hover:bg-white/10"
              }`}
            >
              {t.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
