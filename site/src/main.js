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
