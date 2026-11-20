// DadSaga website (ADR-0040): our own script, served from this site only. It sends nothing anywhere.

// Super Dad and the baby cheer when tapped, for as long as they do in the app (450 ms).
for (const figure of document.querySelectorAll(".figure")) {
  figure.addEventListener("click", () => {
    if (figure.classList.contains("cheering")) return;
    figure.classList.add("cheering");
    navigator.vibrate?.(10);
    setTimeout(() => figure.classList.remove("cheering"), 450);
  });
}

// The timeline clip plays while it is on screen, and never for visitors who asked for reduced motion: they see the
// poster, a still of the same screen.
const clip = document.querySelector(".clip");
const calm = matchMedia("(prefers-reduced-motion: reduce)");
if (clip && "IntersectionObserver" in window) {
  new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting && !calm.matches) clip.play().catch(() => {});
    else clip.pause();
  }, { threshold: 0.25 }).observe(clip);
}
