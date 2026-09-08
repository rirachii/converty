import { describe, it, expect } from "vitest";
import { parsePages, safePath, uniqueNames } from "../src/engine/utils";
import { mediaArgs } from "../src/engine/media";
import { defaultOptions } from "../src/types";
import { categoryOf } from "../src/catalog";

describe("file processing boundaries", () => {
  it("preserves chosen page order without duplicates", () => {
    expect(parsePages("3, 1-2, 3", 5)).toEqual([2, 0, 1]);
    expect(parsePages("", 2)).toEqual([0, 1]);
  });
  it.each(["0", "2-1", "6", "1,x", "1-", "-2"])(
    "rejects invalid page selection %s",
    (input) => expect(() => parsePages(input, 5)).toThrow(),
  );
  it.each([
    "../secrets.txt",
    "/tmp/file",
    "C:\\file",
    "folder/../../file",
    "x\0y",
  ])("rejects unsafe archive paths %s", (path) =>
    expect(() => safePath(path)).toThrow(),
  );
  it("retains safe archive nesting", () =>
    expect(safePath("folder\\notes.txt")).toBe("folder/notes.txt"));
  it("prevents download collisions including case differences", () => {
    const blob = new Blob(["one"]);
    expect(
      uniqueNames(
        ["photo.png", "Photo.png", "photo-2.png", "notes", "notes"].map(
          (name) => ({ name, blob }),
        ),
      ).map((r) => r.name),
    ).toEqual([
      "photo.png",
      "Photo-2.png",
      "photo-2-2.png",
      "notes",
      "notes-2",
    ]);
  });
  it("rejects zero-length or backwards media ranges", () =>
    expect(() =>
      mediaArgs("in.mov", "out.mp4", true, {
        ...defaultOptions,
        operation: "trim",
        start: 2,
        end: 1,
        format: "mp4",
      }),
    ).toThrow());
  it("does not advertise unsupported native formats", () => {
    expect(categoryOf("portrait.heic")).toBeUndefined();
    expect(categoryOf("archive.rar")).toBeUndefined();
  });
});
