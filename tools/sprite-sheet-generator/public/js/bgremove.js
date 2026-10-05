// bgremove.js — flood-fill background removal from image edges.
//
// Samples the four corners to estimate the background color, then flood-fills
// contiguous background-colored pixels from every edge and makes them
// transparent. Keeps interior pixels of the same color (e.g. sky inside a
// window) intact because it only clears pixels connected to the border.

function colorDist(d, i, r, g, b) {
  const dr = d[i] - r;
  const dg = d[i + 1] - g;
  const db = d[i + 2] - b;
  return Math.sqrt(dr * dr + dg * dg + db * db);
}

/**
 * @param {HTMLCanvasElement} canvas source canvas (mutated copy returned)
 * @param {number} tolerance 0-255 color distance threshold
 * @returns {HTMLCanvasElement} new canvas with background removed
 */
export function removeBackground(canvas, tolerance = 34) {
  const w = canvas.width;
  const h = canvas.height;
  const out = document.createElement('canvas');
  out.width = w;
  out.height = h;
  const octx = out.getContext('2d');
  octx.drawImage(canvas, 0, 0);
  const img = octx.getImageData(0, 0, w, h);
  const d = img.data;

  // estimate background color = average of the four corners
  const corners = [0, (w - 1) * 4, (h - 1) * w * 4, (h * w - 1) * 4];
  let r = 0, g = 0, b = 0;
  for (const c of corners) {
    r += d[c];
    g += d[c + 1];
    b += d[c + 2];
  }
  r = Math.round(r / 4);
  g = Math.round(g / 4);
  b = Math.round(b / 4);

  const visited = new Uint8Array(w * h);
  const stack = [];
  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    const p = y * w + x;
    if (visited[p]) return;
    visited[p] = 1;
    if (colorDist(d, p * 4, r, g, b) <= tolerance) stack.push(p);
  };
  // seed from all border pixels
  for (let x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (let y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (stack.length) {
    const p = stack.pop();
    d[p * 4 + 3] = 0; // clear alpha
    const x = p % w;
    const y = (p / w) | 0;
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }
  octx.putImageData(img, 0, 0);
  return out;
}
