// NIBM Lab dashboard footer — Supun Hewagamage · github.com/supunhg
(() => {
  const add = () => {
    if (document.getElementById("nibm-credit")) return;
    const el = document.createElement("div");
    el.id = "nibm-credit";
    el.innerHTML =
      'NIBM Lab · designed &amp; built by <a href="https://github.com/supunhg" target="_blank" rel="noopener">Supun Hewagamage</a>' +
      ' <span>@supunhg</span>';
    (document.querySelector("#inner_wrapper > .container") || document.body).appendChild(el);
  };
  document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", add) : add();
  new MutationObserver(add).observe(document.documentElement, { childList: true, subtree: true });
})();
