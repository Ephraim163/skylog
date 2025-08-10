export default function Page() {
  const cards = [
    { title: "Active Tasks", value: 0 },
    { title: "Open NCRs", value: 0 },
    { title: "Tools Out", value: 0 },
  ];
  return (
    <div className="grid sm:grid-cols-3 gap-4">
      {cards.map(c=>(
        <div key={c.title} className="border border-[color:var(--border)] rounded-xl p-4 bg-black/10">
          <div className="text-sm text-[color:var(--muted)]">{c.title}</div>
          <div className="text-3xl font-semibold">{c.value}</div>
        </div>
      ))}
    </div>
  );
}
