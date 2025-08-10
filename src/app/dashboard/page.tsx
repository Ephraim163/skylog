export default function DashboardPage() {
  const cards = [
    { label: "Active Tasks", value: 0 },
    { label: "Open NCRs", value: 0 },
    { label: "Tools Out", value: 0 },
  ];
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <div className="grid sm:grid-cols-3 gap-4">
        {cards.map(c => (
          <div key={c.label} className="border border-[color:var(--border)] rounded-xl p-4 bg-black/10">
            <div className="text-sm text-[color:var(--muted)]">{c.label}</div>
            <div className="text-3xl font-semibold">{c.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
