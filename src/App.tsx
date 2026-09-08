import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type DragEvent,
  type ReactNode,
} from "react";
import {
  ArrowDown,
  ArrowDownToLine,
  ArrowLeft,
  ArrowRight,
  ArrowRightLeft,
  Archive,
  Check,
  CheckCheck,
  ChevronDown,
  ChevronRight,
  CircleHelp,
  Code2,
  Crop,
  Download,
  FileImage,
  FileText,
  Files,
  FolderOpen,
  Grid2X2,
  Image,
  Keyboard,
  LoaderCircle,
  LockKeyhole,
  Maximize2,
  Menu,
  Minus,
  Music2,
  PackageOpen,
  Plus,
  ScanLine,
  Scissors,
  Search,
  Settings2,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  Split,
  Trash2,
  Video,
  Volume2,
  VolumeX,
  WandSparkles,
  X,
  Zap,
  type LucideIcon,
} from "lucide-react";
import {
  accept,
  categories,
  categoryOf,
  defaultTarget,
  extension,
  formatsFor,
  tools,
} from "./catalog";
import {
  defaultOptions,
  type Category,
  type Operation,
  type Options,
  type QueueFile,
  type Result,
} from "./types";
import { formatSize, MAX_FILE_SIZE, uniqueNames } from "./engine/utils";
import { sampleAudio, sampleImage, samplePDF } from "./samples";

const categoryIcons: Record<Category, LucideIcon> = {
  image: Image,
  video: Video,
  audio: Music2,
  document: FileText,
  archive: Archive,
};
const toolIcons: Record<Operation, LucideIcon> = {
  convert: ArrowRightLeft,
  compress: ArrowDownToLine,
  resize: Maximize2,
  crop: Crop,
  metadata: ShieldCheck,
  merge: Files,
  split: Split,
  collage: Grid2X2,
  qr: ScanLine,
  trim: Scissors,
  mute: VolumeX,
  speed: Zap,
  snapshot: FileImage,
  normalize: Volume2,
  channels: SlidersHorizontal,
  extract: PackageOpen,
  "create-pdf": FileText,
  text: FileText,
};
type View = "all" | Category | "tools" | "completed";
type DialogState =
  | { kind: "operation"; operation: Operation; ids: string[] }
  | { kind: "about" | "settings" | "help" }
  | null;

function IconButton({
  label,
  onClick,
  children,
  disabled = false,
  className = "",
}: {
  label: string;
  onClick: () => void;
  children: ReactNode;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <button
      type="button"
      className={`icon-button ${className}`}
      title={label}
      aria-label={label}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
}
function FileArt({
  category,
  format,
  preview,
  large = false,
}: {
  category: Category;
  format: string;
  preview?: string;
  large?: boolean;
}) {
  const Icon = categoryIcons[category];
  return (
    <div
      className={`file-art ${category} ${large ? "large" : ""}`}
      aria-hidden="true"
    >
      {preview ? <img src={preview} alt="" /> : <Icon strokeWidth={1.5} />}
      <span>{format.toUpperCase()}</span>
    </div>
  );
}
function Modal({
  title,
  onClose,
  children,
  wide = false,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current!;
    dialog.showModal();
    return () => dialog.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className={`modal ${wide ? "wide" : ""}`}
      onCancel={onClose}
      onClick={(event) => {
        if (event.target === ref.current) {
          const r = ref.current.getBoundingClientRect();
          if (
            event.clientX < r.left ||
            event.clientX > r.right ||
            event.clientY < r.top ||
            event.clientY > r.bottom
          )
            onClose();
        }
      }}
      aria-labelledby="dialog-title"
    >
      <div className="modal-heading">
        <h2 id="dialog-title">{title}</h2>
        <IconButton label="Close dialog" onClick={onClose}>
          <X size={20} />
        </IconButton>
      </div>
      {children}
    </dialog>
  );
}
function readQuality() {
  try {
    const v = Number(localStorage.getItem("converty.quality"));
    return v >= 10 && v <= 100 ? v : 82;
  } catch {
    return 82;
  }
}
function saveResult(result: Result) {
  const url = result.url || URL.createObjectURL(result.blob),
    a = document.createElement("a");
  a.href = url;
  a.download = result.name;
  a.click();
  if (!result.url) setTimeout(() => URL.revokeObjectURL(url), 10000);
}
function eligible(file: QueueFile, operation: Operation) {
  if (operation === "convert") return true;
  const tool = tools.find((t) => t.id === operation)!;
  if (!tool.categories.includes(file.category)) return false;
  if (file.category === "document" && file.format !== "pdf") return false;
  return true;
}

export default function App() {
  const [files, setFiles] = useState<QueueFile[]>([]),
    [view, setView] = useState<View>("all");
  const [dialog, setDialog] = useState<DialogState>(null),
    [query, setQuery] = useState("");
  const [dragging, setDragging] = useState(false),
    [mobileNav, setMobileNav] = useState(false);
  const [busy, setBusy] = useState(false),
    [zipping, setZipping] = useState(false);
  const [notice, setNotice] = useState(""),
    [quality, setQuality] = useState(readQuality);
  const input = useRef<HTMLInputElement>(null),
    abort = useRef<AbortController | null>(null),
    filesRef = useRef(files);
  filesRef.current = files;
  useEffect(
    () => () => {
      for (const f of filesRef.current) {
        if (f.preview) URL.revokeObjectURL(f.preview);
        f.results.forEach((r) => r.url && URL.revokeObjectURL(r.url));
      }
      abort.current?.abort();
    },
    [],
  );
  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(""), 8500);
    return () => clearTimeout(timer);
  }, [notice]);

  const addFiles = useCallback((incoming: File[]) => {
    const accepted: QueueFile[] = [],
      errors: string[] = [];
    for (const file of incoming) {
      const category = categoryOf(file.name),
        format = extension(file.name);
      if (!category) {
        errors.push(`${file.name}: this format is not supported yet.`);
        continue;
      }
      if (file.size > MAX_FILE_SIZE) {
        errors.push(`${file.name}: choose a file smaller than 200 MB.`);
        continue;
      }
      if (!file.size) {
        errors.push(`${file.name}: this file is empty.`);
        continue;
      }
      if (filesRef.current.length + accepted.length >= 50) {
        errors.push("The workspace holds up to 50 files.");
        break;
      }
      accepted.push({
        id: crypto.randomUUID(),
        file,
        category,
        format,
        target: defaultTarget(category, format),
        preview:
          ["image", "video", "audio"].includes(category) &&
          !["tiff", "tif"].includes(format)
            ? URL.createObjectURL(file)
            : undefined,
        status: "ready",
        progress: 0,
        results: [],
      });
    }
    setFiles((current) => [...current, ...accepted]);
    if (accepted.length) {
      setDialog((current) =>
        current?.kind === "operation"
          ? {
              ...current,
              ids: [
                ...current.ids,
                ...accepted
                  .filter((f) => eligible(f, current.operation))
                  .map((f) => f.id),
              ],
            }
          : current,
      );
      setView((current) =>
        current === "all" || accepted.every((f) => f.category === current)
          ? current
          : "all",
      );
    }
    if (errors.length) setNotice(errors.join(" "));
  }, []);
  useEffect(() => {
    const prevent = (event: globalThis.DragEvent) => {
      if (event.dataTransfer?.types.includes("Files")) event.preventDefault();
    };
    window.addEventListener("dragover", prevent);
    window.addEventListener("drop", prevent);
    return () => {
      window.removeEventListener("dragover", prevent);
      window.removeEventListener("drop", prevent);
    };
  }, []);
  function update(id: string, patch: Partial<QueueFile>) {
    setFiles((current) =>
      current.map((f) => (f.id === id ? { ...f, ...patch } : f)),
    );
  }
  async function run(ids: string[], options?: Options) {
    if (busy) return;
    const selected = filesRef.current.filter((f) => ids.includes(f.id));
    if (!selected.length) return;
    setBusy(true);
    setDialog(null);
    setView("all");
    abort.current = new AbortController();
    const signal = abort.current.signal;
    const grouped =
      options && ["merge", "create-pdf", "collage"].includes(options.operation);
    const groups = grouped ? [selected] : selected.map((f) => [f]);
    let successes = 0;
    try {
      const { processFiles } = await import("./engine");
      for (const group of groups) {
        if (signal.aborted) break;
        const lead = group[0];
        update(lead.id, {
          status: "processing",
          progress: 0,
          message: "Getting ready…",
        });
        try {
          const results = await processFiles(
            group.map((f) => f.file),
            options || { ...defaultOptions, quality, format: lead.target },
            (progress, message) => update(lead.id, { progress, message }),
            signal,
          );
          signal.throwIfAborted();
          if (!results.length)
            throw new Error("The operation returned no files.");
          lead.results.forEach((r) => r.url && URL.revokeObjectURL(r.url));
          const ready = uniqueNames(results).map((r) => ({
            ...r,
            url: URL.createObjectURL(r.blob),
          }));
          const outputSize = ready.reduce((n, r) => n + r.blob.size, 0);
          update(lead.id, {
            status: "done",
            progress: 100,
            results: ready,
            message:
              options?.operation === "compress" && outputSize >= lead.file.size
                ? "This copy is not smaller. The original is unchanged."
                : undefined,
          });
          successes++;
        } catch (error) {
          update(lead.id, {
            status: signal.aborted ? "ready" : "error",
            progress: 0,
            message: signal.aborted
              ? "Cancelled. Your original is unchanged."
              : error instanceof Error
                ? error.message
                : "Something went wrong. Try another file.",
          });
        }
      }
      if (signal.aborted)
        setNotice("Processing cancelled. Your originals are unchanged.");
      else if (successes)
        setNotice(
          `${successes === 1 ? "Your file is" : `${successes} files are`} ready to download.`,
        );
    } finally {
      setBusy(false);
      abort.current = null;
    }
  }
  async function cancel() {
    abort.current?.abort();
    const { cancelMedia } = await import("./engine/media");
    cancelMedia();
  }
  const visible = files.filter(
    (f) =>
      (view === "all" ||
        view === "tools" ||
        (view === "completed" ? f.results.length > 0 : f.category === view)) &&
      f.file.name.toLowerCase().includes(query.toLowerCase()),
  );
  const allResults = files.flatMap((f) => f.results);
  const readyFiles = visible.filter((f) => f.status !== "done");
  const openTool = useCallback((operation: Operation, ids?: string[]) => {
    setDialog({
      kind: "operation",
      operation,
      ids:
        ids ||
        filesRef.current.filter((f) => eligible(f, operation)).map((f) => f.id),
    });
  }, []);
  useEffect(() => {
    const keydown = (event: KeyboardEvent) => {
      if (event.key === "o" && (event.metaKey || event.ctrlKey)) {
        event.preventDefault();
        input.current?.click();
      }
      if (
        event.key === "Enter" &&
        (event.metaKey || event.ctrlKey) &&
        !dialog
      ) {
        event.preventDefault();
        void run(readyFiles.map((f) => f.id));
      }
      if (
        event.key === "?" &&
        !["INPUT", "TEXTAREA", "SELECT"].includes(
          (event.target as HTMLElement).tagName,
        ) &&
        !dialog
      ) {
        event.preventDefault();
        setDialog({ kind: "help" });
      }
    };
    window.addEventListener("keydown", keydown);
    return () => window.removeEventListener("keydown", keydown);
  });
  async function downloadAll(results = allResults) {
    if (!results.length || zipping) return;
    if (results.length === 1) {
      saveResult(results[0]);
      return;
    }
    setZipping(true);
    try {
      const { createZip } = await import("./engine/archives");
      saveResult({
        name: "converty-files.zip",
        blob: await createZip(results),
      });
    } catch (error) {
      setNotice(
        error instanceof Error
          ? error.message
          : "Could not create the download.",
      );
    } finally {
      setZipping(false);
    }
  }
  function removeFile(id: string) {
    const file = files.find((f) => f.id === id);
    if (!file || busy) return;
    if (file.preview) URL.revokeObjectURL(file.preview);
    file.results.forEach((r) => r.url && URL.revokeObjectURL(r.url));
    setFiles((current) => current.filter((f) => f.id !== id));
  }
  async function trySample(kind: "image" | "audio" | "document") {
    try {
      addFiles([
        kind === "image"
          ? await sampleImage()
          : kind === "audio"
            ? sampleAudio()
            : await samplePDF(),
      ]);
    } catch {
      setNotice("The sample could not be created. Try adding a file.");
    }
  }
  const navigate = (to: View) => {
    setView(to);
    setQuery("");
    setMobileNav(false);
  };
  const title =
    view === "tools"
      ? "A tool for every little task."
      : view === "completed"
        ? "Ready when you are."
        : view === "all"
          ? "Good things come in any format."
          : `${categories.find((c) => c.id === view)?.name}, in the format you need.`;
  const toolList = tools.filter(
    (t) =>
      (view === "all" ||
        view === "tools" ||
        view === "completed" ||
        t.categories.includes(view)) &&
      (view !== "tools" ||
        `${t.name} ${t.description}`
          .toLowerCase()
          .includes(query.toLowerCase())),
  );

  return (
    <div className="app-shell">
      <input
        ref={input}
        type="file"
        className="sr-only"
        accept={accept}
        multiple
        aria-label="Choose files"
        onChange={(event: ChangeEvent<HTMLInputElement>) => {
          addFiles(Array.from(event.target.files || []));
          event.target.value = "";
        }}
      />
      {mobileNav && (
        <button
          className="nav-scrim"
          aria-label="Close navigation"
          onClick={() => setMobileNav(false)}
        />
      )}
      <aside className={`sidebar ${mobileNav ? "open" : ""}`}>
        <button
          className="brand"
          onClick={() => navigate("all")}
          aria-label="Converty home"
        >
          <span className="brand-mark">
            <ArrowRightLeft size={23} strokeWidth={2.5} />
          </span>
          converty<span className="brand-dot">.</span>
        </button>
        <button className="sidebar-add" onClick={() => input.current?.click()}>
          <Plus size={18} /> Add files <span>⌘ O</span>
        </button>
        <div className="nav-section-label">WORKSPACE</div>
        <nav aria-label="Workspace">
          <button
            className={view === "all" ? "active" : ""}
            onClick={() => navigate("all")}
          >
            <FolderOpen size={18} />
            All files<span className="nav-count">{files.length || ""}</span>
          </button>
          {categories.map(({ id, name }) => {
            const Icon = categoryIcons[id];
            return (
              <button
                key={id}
                className={view === id ? "active" : ""}
                onClick={() => navigate(id)}
              >
                <Icon size={18} />
                {name}
                <span className="nav-count">
                  {files.filter((f) => f.category === id).length || ""}
                </span>
              </button>
            );
          })}
        </nav>
        <div className="nav-divider" />
        <nav aria-label="Tools and results">
          <button
            className={view === "tools" ? "active" : ""}
            onClick={() => navigate("tools")}
          >
            <WandSparkles size={18} />
            All tools<span className="nav-count">{tools.length}</span>
          </button>
          <button
            className={view === "completed" ? "active" : ""}
            onClick={() => navigate("completed")}
          >
            <CheckCheck size={18} />
            Completed
            <span className="nav-count">{allResults.length || ""}</span>
          </button>
        </nav>
        <div className="sidebar-bottom">
          <div className="privacy-note">
            <div className="privacy-icon">
              <LockKeyhole size={18} />
            </div>
            <strong>Yours. And yours only.</strong>
            <p>
              Your files stay on your device.
              <br />
              That’s how it should be.
            </p>
            <button onClick={() => setDialog({ kind: "about" })}>
              How it works <ArrowRight size={13} />
            </button>
          </div>
          <button
            className="settings-nav"
            onClick={() => setDialog({ kind: "settings" })}
          >
            <Settings2 size={17} />
            Preferences
          </button>
          <div className="sidebar-footer">
            <span className="status-dot" />
            Free & open source<span>v0.1</span>
          </div>
        </div>
      </aside>
      <div className="main-shell">
        <header className="topbar">
          <div className="breadcrumb">
            <IconButton
              className="mobile-menu"
              label="Open navigation"
              onClick={() => setMobileNav(true)}
            >
              <Menu size={20} />
            </IconButton>
            <span>Workspace</span>
            <ChevronRight size={13} />
            <strong>
              {view === "all"
                ? "All files"
                : view === "tools"
                  ? "All tools"
                  : view === "completed"
                    ? "Completed"
                    : categories.find((c) => c.id === view)?.name}
            </strong>
          </div>
          <div className="topbar-actions">
            <button
              className="source-link"
              aria-label="Open source"
              onClick={() => setDialog({ kind: "about" })}
            >
              <Code2 size={16} />
              <span>Open source</span>
              <ArrowRight size={13} />
            </button>
            <span className="topbar-divider" />
            <IconButton
              label="Keyboard shortcuts and help"
              onClick={() => setDialog({ kind: "help" })}
            >
              <CircleHelp size={18} />
            </IconButton>
          </div>
        </header>
        <main
          onDragOver={(event: DragEvent) => {
            if (event.dataTransfer.types.includes("Files")) {
              event.preventDefault();
              setDragging(true);
            }
          }}
          onDragLeave={(event) => {
            if (!event.currentTarget.contains(event.relatedTarget as Node))
              setDragging(false);
          }}
          onDrop={(event) => {
            event.preventDefault();
            setDragging(false);
            addFiles(Array.from(event.dataTransfer.files));
          }}
        >
          <div className="page-intro">
            <div>
              <div className="intro-label">
                <span /> YOUR EVERYDAY FILE TOOLKIT
              </div>
              <h1>{title}</h1>
              <p>
                {view === "tools"
                  ? "The small fixes that make your files work for you."
                  : view === "completed"
                    ? "Download your finished files before closing this tab."
                    : "Convert, compress, and make it work. Right here, on your device."}
              </p>
            </div>
            <span className="local-label">
              <ShieldCheck size={15} />
              100% local
            </span>
          </div>
          {view !== "tools" && view !== "completed" && (
            <section
              className={`dropzone ${dragging ? "dragging" : ""} ${files.length ? "compact" : ""}`}
              aria-label="Add files to convert"
            >
              <div className="file-illustration">
                <div className="floating-file left">
                  <FileArt category="document" format="PDF" large />
                </div>
                <div className="floating-file middle">
                  <FileArt category="image" format="JPG" large />
                </div>
                <div className="floating-file right">
                  <FileArt category="video" format="MP4" large />
                </div>
                <span className="illustration-spark one">✦</span>
                <span className="illustration-spark two">+</span>
                <div className="convert-medallion">
                  <ArrowRightLeft size={19} />
                </div>
              </div>
              <div className="dropzone-copy">
                <h2>
                  {dragging
                    ? "A perfect place to drop them."
                    : files.length
                      ? "There’s room for a few more."
                      : "Drop your files. We’ll take it from here."}
                </h2>
                <p>Images, videos, audio, documents & archives</p>
              </div>
              <button
                className="primary-button"
                onClick={() => input.current?.click()}
              >
                <Plus size={18} />
                Choose files
                <ChevronDown size={15} />
              </button>
              {!files.length && (
                <span className="drop-limit">
                  Up to 200 MB per file · No uploads. No sign-up.
                </span>
              )}
            </section>
          )}
          {!files.length && view !== "tools" && view !== "completed" && (
            <div className="sample-row">
              <span>Just looking around? Try a sample</span>
              <button onClick={() => void trySample("image")}>
                <Image size={13} />
                Image
              </button>
              <button onClick={() => void trySample("audio")}>
                <Music2 size={13} />
                Audio
              </button>
              <button onClick={() => void trySample("document")}>
                <FileText size={13} />
                PDF
              </button>
            </div>
          )}
          {(files.length > 0 || view === "completed") && view !== "tools" && (
            <section className="queue-section" aria-label="File workspace">
              <div className="section-heading">
                <h2>
                  {view === "completed" ? "Completed files" : "Your files"}
                  <span className="count-badge">{visible.length}</span>
                </h2>
                <div className="queue-actions">
                  <label className="search-field">
                    <Search size={15} />
                    <input
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder="Find a file…"
                      aria-label="Find a file"
                    />
                  </label>
                  {files.length > 0 && (
                    <IconButton
                      label="Clear all files"
                      disabled={busy}
                      onClick={() => {
                        files.forEach((f) => {
                          if (f.preview) URL.revokeObjectURL(f.preview);
                          f.results.forEach(
                            (r) => r.url && URL.revokeObjectURL(r.url),
                          );
                        });
                        setFiles([]);
                      }}
                    >
                      <Trash2 size={16} />
                    </IconButton>
                  )}
                </div>
              </div>
              {visible.length ? (
                <>
                  <div className="file-list">
                    {visible.map((file) => (
                      <article
                        key={file.id}
                        className={`file-row ${file.status}`}
                      >
                        <div className="file-main">
                          <FileArt
                            category={file.category}
                            format={file.format}
                            preview={
                              file.category === "image"
                                ? file.preview
                                : undefined
                            }
                          />
                          <div className="file-description">
                            <strong title={file.file.name}>
                              {file.file.name}
                            </strong>
                            <span>
                              {formatSize(file.file.size)}
                              <span className="dot-separator">·</span>
                              {file.status === "done" ? (
                                <span className="success-text">
                                  <Check size={12} />
                                  Ready
                                </span>
                              ) : file.status === "processing" ? (
                                file.message
                              ) : file.status === "error" ? (
                                "Couldn’t process this file"
                              ) : (
                                "Ready to convert"
                              )}
                            </span>
                          </div>
                        </div>
                        <div className="file-conversion">
                          {file.status === "processing" ? (
                            <div className="progress-status">
                              <LoaderCircle size={17} className="spin" />
                              <span>{file.progress}%</span>
                            </div>
                          ) : file.status === "done" ? (
                            <button
                              className="download-button"
                              onClick={() => void downloadAll(file.results)}
                              disabled={zipping}
                            >
                              <Download size={15} />
                              <span>
                                {file.results.length > 1
                                  ? `${file.results.length} files`
                                  : formatSize(file.results[0].blob.size)}
                              </span>
                            </button>
                          ) : (
                            <>
                              <ArrowRight size={15} className="format-arrow" />
                              <label className="format-select">
                                <span className="sr-only">
                                  Output format for {file.file.name}
                                </span>
                                <select
                                  value={file.target}
                                  disabled={busy}
                                  onChange={(event) =>
                                    update(file.id, {
                                      target: event.target.value,
                                    })
                                  }
                                >
                                  {formatsFor(file.category, file.format).map(
                                    (format) => (
                                      <option key={format} value={format}>
                                        {format.toUpperCase()}
                                      </option>
                                    ),
                                  )}
                                </select>
                                <ChevronDown size={13} />
                              </label>
                            </>
                          )}
                          <IconButton
                            label={`Edit ${file.file.name}`}
                            onClick={() => openTool("convert", [file.id])}
                            disabled={busy}
                          >
                            <SlidersHorizontal size={17} />
                          </IconButton>
                          <IconButton
                            label={`Remove ${file.file.name}`}
                            onClick={() => removeFile(file.id)}
                            disabled={busy}
                          >
                            <X size={17} />
                          </IconButton>
                        </div>
                        {file.status === "processing" && (
                          <div className="file-progress">
                            <span style={{ width: `${file.progress}%` }} />
                          </div>
                        )}
                        {file.message && file.status !== "processing" && (
                          <div
                            className={`file-message ${file.status === "error" ? "error-message" : ""}`}
                          >
                            {file.message}
                          </div>
                        )}
                        {file.results.length > 0 && (
                          <div className="output-list">
                            {file.results.map((r, i) => (
                              <button key={i} onClick={() => saveResult(r)}>
                                <Check size={12} />
                                <span>{r.name}</span>
                                <ArrowDown size={12} />
                              </button>
                            ))}
                          </div>
                        )}
                      </article>
                    ))}
                  </div>
                  <div className="batch-bar">
                    <span>
                      <LockKeyhole size={13} />
                      Originals stay untouched
                    </span>
                    <div>
                      {allResults.length > 0 && (
                        <button
                          className="secondary-button"
                          onClick={() => void downloadAll()}
                          disabled={zipping}
                        >
                          {zipping ? (
                            <LoaderCircle className="spin" size={15} />
                          ) : (
                            <Download size={15} />
                          )}
                          Download all{allResults.length > 1 ? " as ZIP" : ""}
                        </button>
                      )}
                      {busy ? (
                        <button
                          className="secondary-button"
                          onClick={() => void cancel()}
                        >
                          Cancel processing
                        </button>
                      ) : (
                        readyFiles.length > 0 && (
                          <button
                            className="primary-button"
                            onClick={() =>
                              void run(readyFiles.map((f) => f.id))
                            }
                          >
                            Convert{" "}
                            {readyFiles.length === 1
                              ? "file"
                              : `${readyFiles.length} files`}
                            <ArrowRight size={16} />
                          </button>
                        )
                      )}
                    </div>
                  </div>
                </>
              ) : (
                <div className="empty-results">
                  <CheckCheck size={30} />
                  <h3>
                    {view === "completed"
                      ? "Your finished files will land here."
                      : "No files in this view."}
                  </h3>
                  <p>
                    {view === "completed"
                      ? "Add a file and convert it to get started."
                      : "Try a different search or add a file."}
                  </p>
                  <button
                    className="text-button"
                    onClick={() => navigate("all")}
                  >
                    Back to all files <ArrowRight size={14} />
                  </button>
                </div>
              )}
            </section>
          )}
          {view !== "completed" && (
            <section className="tools-section">
              <div className="section-heading">
                <div>
                  <h2>
                    {view === "tools"
                      ? "All tools"
                      : "More than a format change"}
                    {view === "tools" && (
                      <span className="count-badge">{tools.length}</span>
                    )}
                  </h2>
                  {view !== "tools" && (
                    <p>A few handy tools for the files you use every day.</p>
                  )}
                </div>
                {view === "tools" ? (
                  <label className="search-field">
                    <Search size={15} />
                    <input
                      placeholder="Find a tool…"
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      aria-label="Find a tool"
                    />
                  </label>
                ) : (
                  <button
                    className="text-button"
                    onClick={() => navigate("tools")}
                  >
                    Explore all tools <ArrowRight size={15} />
                  </button>
                )}
              </div>
              <div className="tool-grid">
                {(view === "tools" ? toolList : toolList.slice(0, 6)).map(
                  (tool, i) => {
                    const Icon = toolIcons[tool.id];
                    return (
                      <button
                        key={tool.id}
                        className="tool-card"
                        onClick={() => openTool(tool.id)}
                      >
                        <span className={`tool-icon tone-${i % 6}`}>
                          <Icon size={21} strokeWidth={1.65} />
                        </span>
                        <strong>{tool.name}</strong>
                        <p>{tool.description}</p>
                        <ArrowRight className="tool-arrow" size={16} />
                      </button>
                    );
                  },
                )}
              </div>
              {!toolList.length && (
                <div className="empty-results">
                  <p>No tools match “{query}”.</p>
                  <button className="text-button" onClick={() => setQuery("")}>
                    Clear search
                  </button>
                </div>
              )}
            </section>
          )}
          <footer className="workspace-footer">
            <span>
              <ShieldCheck size={14} />A little utility. A lot of privacy.
            </span>
            <button onClick={() => setDialog({ kind: "help" })}>
              <Keyboard size={14} />
              Keyboard shortcuts<kbd>?</kbd>
            </button>
          </footer>
        </main>
      </div>
      {notice && (
        <div className="toast" role="status">
          <span>{notice}</span>
          <IconButton
            label="Dismiss notification"
            onClick={() => setNotice("")}
          >
            <X size={16} />
          </IconButton>
        </div>
      )}
      {dialog?.kind === "operation" && (
        <OperationDialog
          key={dialog.operation}
          operation={dialog.operation}
          selectedIds={dialog.ids}
          files={files}
          quality={quality}
          busy={busy}
          onClose={() => setDialog(null)}
          onChoose={() => input.current?.click()}
          onTool={(operation, id) => openTool(operation, [id])}
          onRun={(ids, options) => void run(ids, options)}
        />
      )}
      {dialog?.kind === "about" && (
        <Modal
          title="A little utility. Open to everyone."
          onClose={() => setDialog(null)}
        >
          <div className="about-body">
            <span className="about-mark">
              <ArrowRightLeft size={32} />
            </span>
            <p>
              Converty is a free, open-source file toolkit. Your browser does
              the work, and your files stay on your device.
            </p>
            <div className="info-row">
              <LockKeyhole size={19} />
              <div>
                <strong>No file uploads</strong>
                <p>
                  Files and results live in this tab’s memory. Download what you
                  need before you close or reload it.
                </p>
              </div>
            </div>
            <div className="info-row">
              <Code2 size={19} />
              <div>
                <strong>Built to be yours</strong>
                <p>
                  Licensed under GPL-3.0-or-later. Run it on your own server,
                  inspect the source, and make it better.
                </p>
                <a href="/converty-source.zip" download>
                  Download source & setup guide <Download size={13} />
                </a>
              </div>
            </div>
            <div className="info-row">
              <Zap size={19} />
              <div>
                <strong>Local engines</strong>
                <p>
                  Audio and video load a 32 MB processing engine on first use.
                  Larger files take longer than native apps.
                </p>
              </div>
            </div>
            <p className="fine-print">
              An independent project inspired by everyday file workflows. Not
              affiliated with Tangerine. No analytics, accounts, or file storage
              server.
            </p>
          </div>
        </Modal>
      )}
      {dialog?.kind === "settings" && (
        <Modal title="Preferences" onClose={() => setDialog(null)}>
          <div className="settings-body">
            <label className="field-label">
              Default export quality<span>{quality}%</span>
              <input
                type="range"
                min="10"
                max="100"
                value={quality}
                onChange={(event) => {
                  const value = Number(event.target.value);
                  setQuality(value);
                  try {
                    localStorage.setItem("converty.quality", String(value));
                  } catch {
                    /* Session preference still works. */
                  }
                }}
              />
            </label>
            <p className="field-help">
              Used for JPG, WebP, and media conversions. Lower values usually
              make smaller files.
            </p>
            <div className="settings-note">
              <ShieldCheck size={20} />
              <p>
                Only this preference is saved in your browser. File names and
                file content are never stored.
              </p>
            </div>
            <button className="primary-button" onClick={() => setDialog(null)}>
              Done
              <Check size={16} />
            </button>
          </div>
        </Modal>
      )}
      {dialog?.kind === "help" && (
        <Modal title="Make yourself at home." onClose={() => setDialog(null)}>
          <div className="help-body">
            <h3>Keyboard shortcuts</h3>
            <div className="shortcut">
              <span>Add files</span>
              <kbd>⌘ / Ctrl + O</kbd>
            </div>
            <div className="shortcut">
              <span>Convert ready files in this view</span>
              <kbd>⌘ / Ctrl + Enter</kbd>
            </div>
            <div className="shortcut">
              <span>Close a dialog</span>
              <kbd>Esc</kbd>
            </div>
            <div className="shortcut">
              <span>Open this guide</span>
              <kbd>?</kbd>
            </div>
            <h3>Supported inputs</h3>
            {categories.map((c) => (
              <div className="support-row" key={c.id}>
                <strong>{c.name}</strong>
                <span>{c.formats}</span>
              </div>
            ))}
            <p className="fine-print">
              Up to 50 files, 200 MB each. Images up to 40 megapixels. GIF and
              TIFF conversion uses the first frame/page. HEIC, RAR, TAR, OCR,
              video joining, and video splitting are not supported yet. PDF
              image exports use 150 DPI. PDF-to-Word exports selectable text
              without preserving layout. Text-to-PDF uses a Latin font; DOCX
              preserves other scripts.
            </p>
          </div>
        </Modal>
      )}
    </div>
  );
}

function OperationDialog({
  operation,
  selectedIds,
  files,
  quality,
  busy,
  onClose,
  onChoose,
  onRun,
  onTool,
}: {
  operation: Operation;
  selectedIds: string[];
  files: QueueFile[];
  quality: number;
  busy: boolean;
  onClose: () => void;
  onChoose: () => void;
  onRun: (ids: string[], options: Options) => void;
  onTool: (operation: Operation, id: string) => void;
}) {
  const multi = ["merge", "create-pdf", "collage"].includes(operation);
  const candidates = files.filter((f) => eligible(f, operation));
  const [ids, setIds] = useState(multi ? selectedIds : selectedIds.slice(0, 1)),
    [options, setOptions] = useState<Options>({
      ...defaultOptions,
      quality,
      operation,
    });
  const [error, setError] = useState("");
  const selected = candidates.filter((f) => ids.includes(f.id));
  const first = selected[0];
  const [duration, setDuration] = useState(0);
  const mediaRef = useRef<HTMLMediaElement>(null);
  useEffect(() => {
    setIds(multi ? selectedIds : selectedIds.slice(0, 1));
  }, [selectedIds, multi]);
  useEffect(() => {
    if (!first) return;
    let format = first.target;
    if (operation !== "convert") {
      format =
        first.category === "document"
          ? "pdf"
          : first.category === "video"
            ? "mp4"
            : first.category === "audio"
              ? operation === "compress"
                ? "mp3"
                : first.format === "aac"
                  ? "m4a"
                  : first.format
              : ["png", "jpg", "jpeg", "webp", "tiff"].includes(first.format)
                ? first.format.replace("jpeg", "jpg")
                : "png";
      if (operation === "compress" && first.category === "image")
        format = "webp";
      if (["qr", "text"].includes(operation)) format = "txt";
      if (operation === "snapshot") format = "png";
    }
    setOptions((current) => ({ ...current, format }));
    setDuration(0);
  }, [first?.id, operation]);
  const change = <K extends keyof Options>(key: K, value: Options[K]) =>
    setOptions((current) => ({ ...current, [key]: value }));
  const title =
    operation === "convert"
      ? "Convert & edit"
      : tools.find((t) => t.id === operation)!.name;
  const formatChoices = first
    ? operation === "convert"
      ? formatsFor(first.category, first.format)
      : first.category === "image"
        ? ["png", "jpg", "webp", "tiff"]
        : first.category === "audio"
          ? ["mp3", "wav", "m4a", "flac", "ogg"]
          : ["mp4", "mov", "mkv", "webm"]
    : [];
  function submit() {
    setError("");
    if (!selected.length) {
      setError("Choose at least one compatible file.");
      return;
    }
    if (["merge", "collage"].includes(operation) && selected.length < 2) {
      setError("Choose at least two files.");
      return;
    }
    if (
      ["trim", "snapshot"].includes(operation) &&
      (options.start < 0 || (duration > 0 && options.start >= duration))
    ) {
      setError("Choose a start time within the file.");
      return;
    }
    if (
      operation === "trim" &&
      (options.end <= options.start ||
        (duration > 0 && options.end > duration + 0.05))
    ) {
      setError("Choose an end time after the start and within the file.");
      return;
    }
    if (operation === "resize" && !options.width && !options.height) {
      setError("Enter a width or height.");
      return;
    }
    onRun(
      multi ? selected.map((f) => f.id) : selected.slice(0, 1).map((f) => f.id),
      options,
    );
  }
  return (
    <Modal title={title} onClose={onClose} wide={!!first}>
      <div className={`operation-body ${first ? "with-preview" : ""}`}>
        <div className="operation-source">
          <div className="source-label">
            {multi ? "FILES IN WORKSPACE ORDER" : "CHOOSE A FILE"}
            <button onClick={onChoose}>
              <Plus size={13} />
              Add
            </button>
          </div>
          {candidates.length ? (
            <div className="source-file-list">
              {candidates.map((file) => (
                <label
                  key={file.id}
                  className={`source-file ${ids.includes(file.id) ? "selected" : ""}`}
                >
                  <input
                    type={multi ? "checkbox" : "radio"}
                    name="source-file"
                    value={file.id}
                    checked={ids.includes(file.id)}
                    onChange={() =>
                      setIds(
                        multi
                          ? ids.includes(file.id)
                            ? ids.filter((id) => id !== file.id)
                            : [...ids, file.id]
                          : [file.id],
                      )
                    }
                  />
                  <FileArt category={file.category} format={file.format} />
                  <span>
                    {file.file.name}
                    <small>{formatSize(file.file.size)}</small>
                  </span>
                </label>
              ))}
            </div>
          ) : (
            <div className="choose-empty">
              <FolderOpen size={36} />
              <p>
                Add{" "}
                {tools
                  .find((t) => t.id === operation)
                  ?.categories.map((c) =>
                    categories
                      .find((category) => category.id === c)
                      ?.name.toLowerCase(),
                  )
                  .join(", ") || "a file"}{" "}
                to get started.
              </p>
              <button className="primary-button" onClick={onChoose}>
                <Plus size={16} />
                Choose files
              </button>
            </div>
          )}
          {first?.preview && (
            <div
              className={`file-preview ${operation === "crop" ? "crop-preview" : ""}`}
            >
              {first.category === "image" ? (
                <>
                  <img
                    src={first.preview}
                    alt={`Preview of ${first.file.name}`}
                    style={
                      operation === "crop"
                        ? {
                            aspectRatio: options.aspect.replace(":", " / "),
                            objectFit: "cover",
                          }
                        : undefined
                    }
                  />
                  {operation === "crop" && (
                    <span className="crop-hint">
                      Centered {options.aspect} crop
                    </span>
                  )}
                </>
              ) : first.category === "video" ? (
                <video
                  ref={mediaRef as React.RefObject<HTMLVideoElement>}
                  src={first.preview}
                  controls
                  playsInline
                  onLoadedMetadata={(event) => {
                    const value = event.currentTarget.duration;
                    if (Number.isFinite(value)) {
                      setDuration(value);
                      change("end", Number(Math.min(5, value).toFixed(2)));
                    }
                  }}
                  onTimeUpdate={(event) => {
                    if (
                      operation === "trim" &&
                      !event.currentTarget.paused &&
                      event.currentTarget.currentTime >= options.end
                    )
                      event.currentTarget.pause();
                  }}
                />
              ) : (
                <audio
                  ref={mediaRef as React.RefObject<HTMLAudioElement>}
                  src={first.preview}
                  controls
                  onLoadedMetadata={(event) => {
                    const value = event.currentTarget.duration;
                    if (Number.isFinite(value)) {
                      setDuration(value);
                      change("end", Number(Math.min(5, value).toFixed(2)));
                    }
                  }}
                  onTimeUpdate={(event) => {
                    if (
                      operation === "trim" &&
                      !event.currentTarget.paused &&
                      event.currentTarget.currentTime >= options.end
                    )
                      event.currentTarget.pause();
                  }}
                />
              )}
            </div>
          )}
          {multi && (
            <p className="field-help">
              Output follows the order shown above. Remove and re-add files in
              the workspace to change their order.
            </p>
          )}
        </div>
        {first && (
          <div className="operation-controls">
            {![
              "merge",
              "create-pdf",
              "collage",
              "qr",
              "text",
              "split",
              "extract",
              "snapshot",
            ].includes(operation) &&
              (first.category !== "document" || operation === "convert") && (
                <label className="field-label">
                  Output format
                  <select
                    value={options.format}
                    onChange={(event) => change("format", event.target.value)}
                  >
                    {formatChoices.map((format) => (
                      <option value={format} key={format}>
                        {format.toUpperCase()}
                      </option>
                    ))}
                  </select>
                </label>
              )}
            {["convert", "compress", "resize", "crop"].includes(operation) &&
              ["image", "video", "audio"].includes(first.category) && (
                <label className="field-label">
                  Quality<span>{options.quality}%</span>
                  <input
                    type="range"
                    min="10"
                    max="100"
                    value={options.quality}
                    onChange={(event) =>
                      change("quality", Number(event.target.value))
                    }
                  />
                  <small>
                    Smaller file<span>More detail</span>
                  </small>
                </label>
              )}
            {["resize", "compress"].includes(operation) &&
              first.category === "image" && (
                <>
                  <div className="field-pair">
                    <label className="field-label">
                      Width (px)
                      <input
                        type="number"
                        min="0"
                        max="16384"
                        placeholder="Original"
                        value={options.width || ""}
                        onChange={(event) =>
                          change("width", Number(event.target.value))
                        }
                      />
                    </label>
                    <label className="field-label">
                      Height (px)
                      <input
                        type="number"
                        min="0"
                        max="16384"
                        placeholder="Auto"
                        value={options.height || ""}
                        onChange={(event) =>
                          change("height", Number(event.target.value))
                        }
                      />
                    </label>
                  </div>
                  <p className="field-help">
                    Leave one dimension blank to keep the aspect ratio.
                  </p>
                </>
              )}
            {operation === "crop" && (
              <>
                <label className="field-label">
                  Aspect ratio
                  <select
                    value={options.aspect}
                    onChange={(event) => change("aspect", event.target.value)}
                  >
                    <option value="1:1">Square · 1:1</option>
                    <option value="4:3">Landscape · 4:3</option>
                    <option value="16:9">Widescreen · 16:9</option>
                    <option value="3:4">Portrait · 3:4</option>
                    <option value="9:16">Vertical · 9:16</option>
                  </select>
                </label>
                <p className="field-help">
                  Crops around the center of your image or video.
                </p>
              </>
            )}
            {["trim", "snapshot"].includes(operation) && (
              <>
                <div className="field-pair">
                  <label className="field-label">
                    {operation === "snapshot" ? "Time" : "Start"} (seconds)
                    <input
                      type="number"
                      min="0"
                      step="0.1"
                      max={duration || undefined}
                      value={options.start}
                      onChange={(event) => {
                        change("start", Number(event.target.value));
                        if (mediaRef.current)
                          mediaRef.current.currentTime = Number(
                            event.target.value,
                          );
                      }}
                    />
                  </label>
                  {operation === "trim" && (
                    <label className="field-label">
                      End (seconds)
                      <input
                        type="number"
                        min="0"
                        step="0.1"
                        max={duration || undefined}
                        value={options.end}
                        onChange={(event) =>
                          change("end", Number(event.target.value))
                        }
                      />
                    </label>
                  )}
                </div>
                {duration > 0 && (
                  <p className="field-help">
                    Duration: {duration.toFixed(2)} seconds.
                  </p>
                )}
                {operation === "trim" && (
                  <button
                    className="secondary-button"
                    onClick={() => {
                      if (mediaRef.current) {
                        mediaRef.current.currentTime = options.start;
                        void mediaRef.current.play().catch(() => {});
                      }
                    }}
                  >
                    Preview selected range
                  </button>
                )}
              </>
            )}
            {operation === "speed" && (
              <label className="field-label">
                Playback speed
                <select
                  value={options.speed}
                  onChange={(event) =>
                    change("speed", Number(event.target.value))
                  }
                >
                  <option value="0.5">0.5× · Slower</option>
                  <option value="1.5">1.5× · Faster</option>
                  <option value="2">2× · Faster</option>
                </select>
              </label>
            )}
            {operation === "channels" && (
              <label className="field-label">
                Audio channels
                <select
                  value={options.channels}
                  onChange={(event) =>
                    change("channels", Number(event.target.value))
                  }
                >
                  <option value="1">Mono · 1 channel</option>
                  <option value="2">Stereo · 2 channels</option>
                </select>
                <p className="field-help">
                  Mono-to-stereo duplicates the same audio in both channels.
                </p>
              </label>
            )}
            {first.format === "pdf" &&
              !["merge", "metadata", "compress"].includes(operation) && (
                <label className="field-label">
                  Pages
                  <input
                    placeholder="All pages, or 1, 3-5"
                    value={options.pages}
                    onChange={(event) => change("pages", event.target.value)}
                  />
                </label>
              )}
            {operation === "collage" && (
              <div className="field-pair">
                <label className="field-label">
                  Columns
                  <select
                    value={options.columns}
                    onChange={(event) =>
                      change("columns", Number(event.target.value))
                    }
                  >
                    {[1, 2, 3, 4].map((n) => (
                      <option key={n}>{n}</option>
                    ))}
                  </select>
                </label>
                <label className="field-label">
                  Spacing (px)
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={options.gap}
                    onChange={(event) =>
                      change("gap", Number(event.target.value))
                    }
                  />
                </label>
              </div>
            )}
            {operation === "metadata" && (
              <p className="operation-note">
                {first.category === "document"
                  ? "Creates a PDF copy without document-level author, title, creator, or XMP fields. Page content and annotations can still contain personal information."
                  : first.category === "image"
                    ? "Re-encodes the first frame without EXIF, GPS, or embedded image tags."
                    : "Removes file-level tags and chapters. Visible or spoken personal information stays in the media."}
              </p>
            )}
            {operation === "compress" && (
              <p className="operation-note">
                {first.category === "document"
                  ? "Rebuilds the PDF with compact object streams. Existing images keep their quality. Already optimized PDFs may not get smaller."
                  : "An already optimized file may not get smaller. You can compare the result with the original."}
              </p>
            )}
            {operation === "qr" && (
              <p className="operation-note">
                Reads one QR code per image or PDF page and saves the text.
                Links are not opened automatically.
              </p>
            )}
            {options.format === "docx" && (
              <p className="operation-note">
                PDFs export selectable text into an editable Word document.
                Layout and embedded images are not preserved.
              </p>
            )}
            {["gif", "tiff", "tif"].includes(first.format) && (
              <p className="operation-note">
                Image operations use the first frame or page.
              </p>
            )}
            {["audio", "video"].includes(first.category) && (
              <p className="engine-note">
                <Zap size={14} />
                First use loads a 32 MB local media engine.
              </p>
            )}
            {operation === "convert" && (
              <div className="context-tools">
                <span>Or try a tool</span>
                {tools
                  .filter((t) => eligible(first, t.id) && !t.multi)
                  .slice(0, 4)
                  .map((t) => (
                    <button key={t.id} onClick={() => onTool(t.id, first.id)}>
                      {t.name}
                      <ArrowRight size={12} />
                    </button>
                  ))}
              </div>
            )}
          </div>
        )}
      </div>
      {error && (
        <p className="dialog-error" role="alert">
          {error}
        </p>
      )}
      <div className="modal-footer">
        <span>
          <LockKeyhole size={13} />
          Processed on your device
        </span>
        <button
          className="primary-button"
          disabled={!first || busy}
          onClick={submit}
        >
          {operation === "convert" ? "Convert file" : "Apply tool"}
          <ArrowRight size={16} />
        </button>
      </div>
    </Modal>
  );
}
