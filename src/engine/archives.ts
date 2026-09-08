import { unzip, zip, gunzip, gzip } from "fflate";
import type { Result } from "../types";
import {
  baseName,
  bytesBlob,
  MAX_EXPANDED_SIZE,
  safePath,
  uniqueNames,
} from "./utils";

export async function createZip(results: Result[]): Promise<Blob> {
  const files: Record<string, Uint8Array> = Object.create(null);
  for (const result of uniqueNames(results))
    files[safePath(result.name)] = new Uint8Array(
      await result.blob.arrayBuffer(),
    );
  return new Promise((resolve, reject) =>
    zip(files, { level: 6 }, (error, data) =>
      error ? reject(error) : resolve(bytesBlob(data, "application/zip")),
    ),
  );
}
export async function extractArchive(file: File): Promise<Result[]> {
  const buffer = new Uint8Array(await file.arrayBuffer());
  if (file.name.toLowerCase().endsWith(".zip")) {
    return new Promise((resolve, reject) => {
      let total = 0,
        count = 0,
        invalid: Error | undefined;
      unzip(
        buffer,
        {
          filter: (entry) => {
            try {
              safePath(entry.name);
              total += entry.originalSize;
              count++;
              if (total > MAX_EXPANDED_SIZE || count > 500)
                throw new Error(
                  "Archives are limited to 500 entries and 300 MB unpacked.",
                );
              return !entry.name.endsWith("/");
            } catch (error) {
              invalid = error as Error;
              return false;
            }
          },
        },
        (error, files) => {
          if (invalid || error) {
            reject(invalid || error);
            return;
          }
          const results = Object.entries(files).map(([name, data]) => ({
            name: safePath(name),
            blob: bytesBlob(data, "application/octet-stream"),
          }));
          if (!results.length) reject(new Error("This archive has no files."));
          else resolve(results);
        },
      );
    });
  }
  if (buffer.length < 18) throw new Error("This GZIP file is incomplete.");
  const size = new DataView(buffer.buffer).getUint32(buffer.length - 4, true);
  if (size > MAX_EXPANDED_SIZE)
    throw new Error("GZIP output is limited to 300 MB.");
  return new Promise((resolve, reject) =>
    gunzip(buffer, (error, data) => {
      if (error) reject(error);
      else if (data.length > MAX_EXPANDED_SIZE)
        reject(new Error("The expanded file is too large."));
      else
        resolve([
          {
            name: baseName(file.name),
            blob: bytesBlob(data, "application/octet-stream"),
          },
        ]);
    }),
  );
}
export async function processArchive(
  file: File,
  format: string,
): Promise<Result[]> {
  const results = await extractArchive(file);
  if (format === "zip")
    return [
      {
        name: `${baseName(file.name)}-repacked.zip`,
        blob: await createZip(results),
      },
    ];
  if (results.length !== 1)
    throw new Error(
      "GZIP supports a single file. Choose ZIP for multiple files.",
    );
  const data = new Uint8Array(await results[0].blob.arrayBuffer());
  return new Promise((resolve, reject) =>
    gzip(data, { level: 6 }, (error, data) =>
      error
        ? reject(error)
        : resolve([
            {
              name: `${results[0].name}.gz`,
              blob: bytesBlob(data, "application/gzip"),
            },
          ]),
    ),
  );
}
