// The entry point: `ChartsJL.mount(element)` attaches the runtime to a chart
// written by Charts.jl. Every chart on a page carries the runtime, so the
// first copy defines the global and the rest reuse it.

import { Chart } from './chart.ts';

export const version = '0.2.0';

export function mount(root: HTMLElement | null): Chart | undefined {
  if (!root) return undefined;
  const r = root as HTMLElement & { _cj?: Chart };
  if (r._cj) return r._cj;
  try {
    r._cj = new Chart(root);
  } catch (err) {
    // the chart stays as Julia drew it: complete, and static
    console.error('Charts.jl: the interactive layer could not start', err);
  }
  return r._cj;
}

const g = globalThis as unknown as { ChartsJL?: { mount: typeof mount; version: string } };
if (!g.ChartsJL || g.ChartsJL.version < version) g.ChartsJL = { mount, version };
