import "@fontsource-variable/manrope";
import {
  createIcons,
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  CodeXml,
  Check,
  FileImage,
  MousePointer2,
  Plus,
  FileCheck2,
  Keyboard,
  Image,
  Film,
  AudioLines,
  Files,
  Archive,
  SlidersHorizontal,
  Info,
  FileText,
  Folder,
  HardDrive,
  CopyCheck,
  PanelLeft,
} from "lucide";

createIcons({
  icons: {
    ArrowDown,
    ArrowRight,
    ArrowUpRight,
    CodeXml,
    Check,
    FileImage,
    MousePointer2,
    Plus,
    FileCheck2,
    Keyboard,
    Image,
    Film,
    AudioLines,
    Files,
    Archive,
    SlidersHorizontal,
    Info,
    FileText,
    Folder,
    HardDrive,
    CopyCheck,
    PanelLeft,
  },
  attrs: { "stroke-width": 1.7 },
});

const tabs = [...document.querySelectorAll('[role="tab"]')];
function revealInstallationHelp() {
  if (location.hash === "#install")
    document.getElementById("install").open = true;
}
window.addEventListener("hashchange", revealInstallationHelp);
document.querySelectorAll('a[href="#install"]').forEach((link) => {
  link.addEventListener("click", () => {
    document.getElementById("install").open = true;
  });
});
revealInstallationHelp();

for (const copyCommand of document.querySelectorAll("[data-copy-command]")) {
  if (navigator.clipboard?.writeText) {
    copyCommand.hidden = false;
    copyCommand.addEventListener("click", async () => {
      const install = copyCommand.closest(".homebrew-install");
      const status = install.querySelector(".copy-status");
      try {
        await navigator.clipboard.writeText(
          install.querySelector("code").textContent.trim(),
        );
        status.textContent = "Install command copied. Paste it into Terminal.";
      } catch {
        status.textContent = "Select the command and copy it manually.";
      }
    });
  }
}

const demo = document.querySelector("[data-demo-video]");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
function updateDemoPlayback() {
  if (reducedMotion.matches) demo.pause();
  else demo.play().catch(() => {}); // Native controls remain available if autoplay is blocked.
}
reducedMotion.addEventListener("change", updateDemoPlayback);
updateDemoPlayback();

function selectTab(tab) {
  tabs.forEach((item) => {
    const selected = item === tab;
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.getElementById(item.getAttribute("aria-controls")).hidden =
      !selected;
  });
}
tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => selectTab(tab));
  tab.addEventListener("keydown", (event) => {
    let next;
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
    if (event.key === "ArrowLeft")
      next = (index - 1 + tabs.length) % tabs.length;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = tabs.length - 1;
    if (next === undefined) return;
    event.preventDefault();
    tabs[next].focus();
    selectTab(tabs[next]);
  });
});
