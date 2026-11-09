export interface Bin {
  from: number;
  to: number;
  count: number;
  includesMe: boolean;
}

// Insights §3.2 I-10: Sturges' rule capped at `maxBins`, over whole-number pass counts; bounds are inclusive.
export function sturgesBins(values: number[], maxBins: number, mine: number | null): Bin[] {
  if (values.length === 0) return [];
  const min = Math.min(...values);
  const max = Math.max(...values);
  const k = Math.min(maxBins, Math.max(1, Math.ceil(Math.log2(values.length) + 1)));
  const width = Math.max(1, Math.ceil((max - min + 1) / k));
  const bins: Bin[] = [];
  for (let from = min; from <= max; from += width) {
    const to = from + width - 1;
    bins.push({
      from,
      to,
      count: values.filter((v) => v >= from && v <= to).length,
      includesMe: mine !== null && mine >= from && mine <= to,
    });
  }
  return bins;
}

// Insights §7: a bin with fewer than `minCount` people would point at someone, so it joins a neighbour.
export function mergeSmallBins(bins: Bin[], minCount: number): Bin[] {
  const out = bins.map((b) => ({ ...b }));
  for (;;) {
    const index = out.findIndex((b) => b.count < minCount);
    if (index === -1 || out.length < 2) return out;
    const left = out[index - 1];
    const right = out[index + 1];
    const into = !right || (left && left.count <= right.count) ? index - 1 : index + 1;
    const [a, b] = [out[Math.min(index, into)], out[Math.max(index, into)]];
    if (!a || !b) return out;
    out.splice(Math.min(index, into), 2, {
      from: a.from,
      to: b.to,
      count: a.count + b.count,
      includesMe: a.includesMe || b.includesMe,
    });
  }
}
