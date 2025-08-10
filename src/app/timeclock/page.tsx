"use client";
import { useEffect,useState } from "react";
type Row = { t:string; kind:"IN"|"OUT"; lat?:number; lng?:number };
const GEOFENCE = { lat:25.2532, lng:55.3657, radius_m:200 };

export default function Page() {
  const [inOut,setInOut]=useState<"in"|"out"|null>(null);
  const [log,setLog]=useState<Row[]>([]);
  useEffect(()=>{ const s=localStorage.getItem("clocklog"); if(s) setLog(JSON.parse(s)); },[]);
  useEffect(()=>{ localStorage.setItem("clocklog", JSON.stringify(log)); },[log]);

  const within=(lat:number,lng:number)=>{ const R=6371000,toRad=(d:number)=>d*Math.PI/180;
    const dLat=toRad(lat-GEOFENCE.lat), dLng=toRad(lng-GEOFENCE.lng);
    const a=Math.sin(dLat/2)**2+Math.cos(toRad(GEOFENCE.lat))*Math.cos(toRad(lat))*Math.sin(dLng/2)**2;
    return 2*R*Math.asin(Math.sqrt(a))<=GEOFENCE.radius_m; };

  const stamp=async(kind:"IN"|"OUT")=>{
    let lat:number|undefined,lng:number|undefined;
    try{
      const pos=await new Promise<GeolocationPosition>((res,rej)=>
        navigator.geolocation.getCurrentPosition(res,rej,{enableHighAccuracy:true,timeout:5000}));
      lat=pos.coords.latitude; lng=pos.coords.longitude;
      if(!within(lat,lng)){ alert("Outside site geofence"); return; }
    }catch{}
    setInOut(kind==="IN"?"in":"out");
    setLog(v=>[{ t:new Date().toISOString(), kind, lat, lng }, ...v]);
  };

  const exportCSV=()=>{ const rows=[["time_iso","event","lat","lng"],...log.map(r=>[r.t,r.kind,r.lat??"",r.lng??""])];
    const csv=rows.map(r=>r.join(",")).join("\n"); const url=URL.createObjectURL(new Blob([csv],{type:"text/csv"}));
    const a=document.createElement("a"); a.href=url; a.download="timeclock.csv"; a.click(); URL.revokeObjectURL(url); };

  return (<div className="space-y-4">
    <div className="flex gap-2">
      <button onClick={()=>stamp("IN")} className="px-4 py-2 rounded bg-[color:var(--ok)] text-white">Clock In</button>
      <button onClick={()=>stamp("OUT")} className="px-4 py-2 rounded bg-[color:var(--bad)] text-white">Clock Out</button>
      <button onClick={exportCSV} className="px-4 py-2 rounded border border-[color:var(--border)]">Export CSV</button>
    </div>
    <div className="text-sm">Status: <b>{inOut ?? "—"}</b></div>
    <div className="text-xs text-[color:var(--muted)]">Geofence {GEOFENCE.lat},{GEOFENCE.lng} · {GEOFENCE.radius_m} m</div>
    <table className="w-full text-sm"><thead><tr><th className="text-left">Time (UTC)</th><th>Event</th><th>Lat</th><th>Lng</th></tr></thead>
      <tbody>{log.map((r,i)=>(
        <tr key={i} className="border-b border-[color:var(--border)]"><td>{r.t}</td><td>{r.kind}</td><td>{r.lat??""}</td><td>{r.lng??""}</td></tr>
      ))}</tbody></table>
  </div>);
}
