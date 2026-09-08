export type Category = "image" | "video" | "audio" | "document" | "archive";
export type Operation =
  | "convert"
  | "compress"
  | "resize"
  | "crop"
  | "metadata"
  | "merge"
  | "split"
  | "collage"
  | "qr"
  | "trim"
  | "mute"
  | "speed"
  | "snapshot"
  | "normalize"
  | "channels"
  | "extract"
  | "create-pdf"
  | "text";
export type QueueFile = {
  id: string;
  file: File;
  category: Category;
  format: string;
  target: string;
  preview?: string;
  status: "ready" | "processing" | "done" | "error";
  progress: number;
  message?: string;
  results: Result[];
};
export type Result = { name: string; blob: Blob; url?: string };
export type Options = {
  operation: Operation;
  format: string;
  quality: number;
  width: number;
  height: number;
  aspect: string;
  start: number;
  end: number;
  speed: number;
  channels: number;
  pages: string;
  columns: number;
  gap: number;
};
export const defaultOptions: Options = {
  operation: "convert",
  format: "",
  quality: 82,
  width: 0,
  height: 0,
  aspect: "1:1",
  start: 0,
  end: 5,
  speed: 2,
  channels: 1,
  pages: "",
  columns: 2,
  gap: 16,
};
export type Tool = {
  id: Operation;
  name: string;
  description: string;
  categories: Category[];
  multi?: boolean;
};
