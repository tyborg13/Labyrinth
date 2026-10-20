// Top-down tactical diagrams of the 7x7 board. Coordinates: x right, y down (y=0 is the far wall).
function drawBoard(host, spec) {
  const C = 54, P = 30, N = 7, W = N * C + P * 2;
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", `0 0 ${W} ${W}`); svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", spec.alt || "Board diagram");
  const el = (n, a, parent = svg) => { const e = document.createElementNS(ns, n); for (const k in a) e.setAttribute(k, a[k]); parent.appendChild(e); return e; };
  const cx = (x) => P + x * C + C / 2, cy = (y) => P + y * C + C / 2;
  el("rect", { x: P - 10, y: P - 10, width: N * C + 20, height: N * C + 20, rx: 6, class: "b-wall" });
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++)
    el("rect", { x: P + x * C + 1, y: P + y * C + 1, width: C - 2, height: C - 2, rx: 3, class: "b-floor" });
  const tint = (cells, cls) => (cells || []).forEach(([x, y]) => el("rect", { x: P + x * C + 3, y: P + y * C + 3, width: C - 6, height: C - 6, rx: 3, class: cls }));
  tint(spec.aura, "b-aura"); tint(spec.threat, "b-threat"); tint(spec.ice, "b-ice"); tint(spec.safe, "b-safe");
  (spec.doors || []).forEach((d) => {
    const [x, y] = d.at; const side = d.side;
    const bar = side === "top" ? { x: P + x * C + 6, y: P - 14, width: C - 12, height: 10 } : side === "bottom" ? { x: P + x * C + 6, y: P + N * C + 4, width: C - 12, height: 10 }
      : side === "right" ? { x: P + N * C + 4, y: P + y * C + 6, width: 10, height: C - 12 } : { x: P - 14, y: P + y * C + 6, width: 10, height: C - 12 };
    el("rect", Object.assign(bar, { rx: 2, class: d.entry ? "b-entry" : "b-door" }));
    if (!d.entry) el("rect", { x: P + x * C + 4, y: P + y * C + 4, width: C - 8, height: C - 8, rx: 3, class: "b-threshold" });
  });
  (spec.pillars || []).forEach(([x, y]) => el("rect", { x: P + x * C + 5, y: P + y * C + 5, width: C - 10, height: C - 10, rx: 4, class: "b-pillar" }));
  (spec.crates || []).forEach(([x, y]) => el("rect", { x: P + x * C + 13, y: P + y * C + 13, width: C - 26, height: C - 26, rx: 2, class: "b-crate" }));
  (spec.paths || []).forEach((p) => {
    const d = p.pts.map(([x, y], i) => `${i ? "L" : "M"}${cx(x)},${cy(y)}`).join(" ");
    el("path", { d, class: "b-path b-path-" + p.kind });
    const [ex, ey] = p.pts[p.pts.length - 1];
    if (p.kind !== "blocked") el("circle", { cx: cx(ex), cy: cy(ey), r: 4, class: "b-path-end b-path-" + p.kind });
  });
  (spec.units || []).forEach((u) => {
    const g = el("g", { class: "b-unit b-" + u.t });
    el("circle", { cx: cx(u.x), cy: cy(u.y), r: C * 0.34 }, g);
    const t = el("text", { x: cx(u.x), y: cy(u.y) + 5, "text-anchor": "middle" }, g); t.textContent = u.label;
    if (u.t === "leader") { const c = el("path", { d: `M${cx(u.x) - 11},${cy(u.y) - 19} l4,-9 l7,6 l7,-6 l4,9 z`, class: "b-crown" }, g); }
  });
  (spec.notes || []).forEach((n) => { const t = el("text", { x: cx(n.x), y: cy(n.y) + (n.dy || 0), "text-anchor": "middle", class: "b-note" }); t.textContent = n.text; });
  host.appendChild(svg);
}
