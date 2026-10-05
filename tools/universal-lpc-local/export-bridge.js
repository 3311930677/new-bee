// Save files exported by this local generator into the four-role trial folder.
// The original browser download remains available.
(() => {
  const role = new URLSearchParams(location.search).get('role');
  if (!['zs', 'ck', 'fs', 'fz'].includes(role)) return;
  const saved = new WeakSet();
  function capture(anchor) {
    if (!anchor.download || saved.has(anchor) || !/^(blob:|data:)/.test(anchor.href)) return;
    saved.add(anchor);
    fetch(anchor.href).then(r => r.blob()).then(blob => fetch('/__local/export', {
      method: 'POST', body: blob,
      headers: {'X-Role': role, 'X-Filename': encodeURIComponent(anchor.download)}
    })).then(r => {
      if (!r.ok) throw new Error('Local export failed: ' + r.status);
      return r.json();
    }).then(result => console.info('LPC_LOCAL_SAVED', result)).catch(console.error);
  }
  const click = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function(...args) {capture(this); return click.apply(this, args);};
  const dispatch = HTMLAnchorElement.prototype.dispatchEvent;
  HTMLAnchorElement.prototype.dispatchEvent = function(event) {
    if (event.type === 'click') capture(this);
    return dispatch.call(this, event);
  };
})();
