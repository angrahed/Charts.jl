// Made-up data for the specimens. The regions are generic on purpose: the
// charts show what the defaults do, not facts about any economy.

export const YEARS = Array.from({ length: 17 }, (_, i) => 2010 + i);

export const MACRO = {
  East: [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9],
  South: [4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1],
  North: [2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4],
  West: [1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3],
};

export const series = (palette, opts = {}) => Object.entries(MACRO).map(([name, v], i) => ({
  name, values: v.map((y, k) => [YEARS[k], y]), color: palette[i % palette.length], ...(opts[name] || {}),
}));
