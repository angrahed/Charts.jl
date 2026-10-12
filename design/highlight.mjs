// Quiet Julia highlighting for the code blocks and the code in figures.

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const KW = 'function|end|do|using|import|struct|mutable|abstract|primitive|type|if|else|elseif|for|while|in|return|const|let|begin|module|export|true|false|nothing|where|macro|try|catch|finally|isa';
const TOKEN = new RegExp([
  '(?<c>#[^\\n]*)',
  '(?<s>"(?:\\\\.|[^"\\\\\\n])*")',
  '(?<m>@[A-Za-z_]\\w*)',
  '(?<y>(?<![\\w)\\]}.\'"])::?(?=[A-Za-z_])(?<!::)[A-Za-z_][\\w!]*)',
  `(?<k>\\b(?:${KW})\\b)`,
  '(?<num>\\b\\d[\\d_]*(?:\\.\\d+)?(?:e-?\\d+)?(?:mm|pt|px|cm|in|ms)?\\b)',
  '(?<f>\\b[A-Za-z_][\\w!]*(?=\\())',
  '(?<o>\\|>|=>|(?<=\\s)[*+|/](?=\\s)|->)',
].join('|'), 'g');

export function highlightJulia(src) {
  let out = '', last = 0;
  for (const m of src.matchAll(TOKEN)) {
    out += esc(src.slice(last, m.index));
    const [k] = Object.entries(m.groups).find(([, v]) => v != null);
    const cls = { c: 'hl-c', s: 'hl-s', m: 'hl-m', y: 'hl-y', k: 'hl-k', num: 'hl-n', f: 'hl-f', o: 'hl-o' }[k];
    out += `<span class="${cls}">${esc(m[0])}</span>`;
    last = m.index + m[0].length;
  }
  return out + esc(src.slice(last));
}

export const codeBlock = src => `<pre class="code lang-julia"><code>${highlightJulia(src)}</code></pre>`;
