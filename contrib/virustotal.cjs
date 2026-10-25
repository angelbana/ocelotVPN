"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");
const { createHash, randomBytes } = require("node:crypto");
const { setTimeout: sleep } = require("node:timers/promises");

const API = "https://www.virustotal.com/api/v3";
const SMALL_FILE = 32 * 1024 * 1024;
const MAX_FILE = 650 * 1024 * 1024;
const MAX_WAIT = 15 * 60_000;

class ScanError extends Error {}
class RequestError extends ScanError {
  constructor(status, { missing = false, transient = false, delay = 0 } = {}) {
    super(status ? `VirusTotal HTTP ${status}; verification is incomplete.` :
      "VirusTotal request failed or timed out; verification is incomplete.");
    this.status = status;
    this.missing = missing;
    this.transient = transient;
    this.delay = delay;
  }
}

async function sha256(file) {
  const hash = createHash("sha256");
  for await (const chunk of fs.createReadStream(file)) hash.update(chunk);
  return hash.digest("hex");
}

async function publicArtifact(file) {
  const stat = await fsp.lstat(file);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1)
    throw new ScanError("The final artifact must be a regular file, not a link.");
  if (stat.size < 1 || stat.size > MAX_FILE)
    throw new ScanError("The final artifact must contain 1 byte to 650 MiB.");
  const resolved = await fsp.realpath(file);
  const hash = await sha256(resolved);
  const after = await fsp.stat(resolved);
  if (stat.size !== after.size || stat.mtimeMs !== after.mtimeMs || stat.ctimeMs !== after.ctimeMs)
    throw new ScanError("The final artifact changed while calculating SHA256.");
  return { file: resolved, filename: path.basename(resolved), size: stat.size, sha256: hash };
}

function trustedUrl(value) {
  let url;
  try { url = new URL(value); } catch { throw new ScanError("Invalid VirusTotal URL."); }
  if (url.protocol !== "https:" || url.port || url.username || url.password || url.hash ||
      !(url.hostname === "virustotal.com" || url.hostname.endsWith(".virustotal.com")))
    throw new ScanError("Refusing a URL outside the VirusTotal HTTPS service.");
  return url.href;
}

function statistics(value) {
  if (!value || typeof value !== "object" || Array.isArray(value) ||
      !["malicious", "suspicious", "harmless", "undetected"].every((name) => Object.hasOwn(value, name)))
    throw new ScanError("VirusTotal returned incomplete analysis statistics.");
  const result = {};
  for (const [name, count] of Object.entries(value)) {
    if (!/^[a-z][a-z-]*$/.test(name) || !Number.isSafeInteger(count) || count < 0)
      throw new ScanError("VirusTotal returned invalid analysis statistics.");
    result[name] = count;
  }
  if (!Object.values(result).some((count) => count > 0)) return undefined;
  return result;
}

function analysisDate(value, now) {
  if (!Number.isSafeInteger(value) || value <= 0 || value * 1000 > now + 300_000 ||
      !Number.isFinite(new Date(value * 1000).getTime()))
    throw new ScanError("VirusTotal returned an invalid analysis date.");
  return new Date(value * 1000).toISOString();
}

function fileResult(response, hash, now) {
  const attributes = response?.data?.attributes;
  if (response?.data?.id !== hash || attributes?.sha256 !== hash)
    throw new ScanError("VirusTotal's report does not match the final artifact SHA256.");
  if (attributes.last_analysis_date == null || attributes.last_analysis_stats == null) return undefined;
  const date = analysisDate(attributes.last_analysis_date, now);
  const stats = statistics(attributes.last_analysis_stats);
  return stats ? { analysisDate: date, stats } : undefined;
}

function retryDelay(value, now) {
  if (!value) return 60_000;
  const seconds = Number(value);
  const delay = Number.isFinite(seconds) && seconds >= 0 ? seconds * 1000 : Date.parse(value) - now;
  return Math.max(60_000, Number.isFinite(delay) ? delay : 60_000);
}

function createClient({ key = "", fetchImpl = globalThis.fetch, now = Date.now, pause = sleep,
  totalTimeoutMs = MAX_WAIT, requestTimeoutMs = 60_000, intervalMs = 20_000,
  maxAttempts = 3, maxRequests = 500 } = {}) {
  const deadline = now() + Math.min(MAX_WAIT, Math.max(1, totalTimeoutMs));
  const interval = Math.max(20_000, intervalMs);
  const attempts = Math.max(1, Math.min(3, maxAttempts));
  let lastRequest = -Infinity;
  let requests = 0;
  async function wait(milliseconds) {
    if (now() + milliseconds >= deadline)
      throw new ScanError("VirusTotal's 15-minute waiting limit reached; verification is incomplete.");
    await pause(Math.max(0, milliseconds));
  }
  async function once(url, { method = "GET", body = undefined, minimumInterval = interval } = {}) {
    url = trustedUrl(url);
    await wait(Math.max(0, lastRequest + Math.max(interval, minimumInterval) - now()));
    if (requests >= Math.min(500, maxRequests))
      throw new ScanError("VirusTotal request budget exhausted; verification is incomplete.");
    let payload;
    if (body) payload = await body();
    if (now() >= deadline) throw new ScanError("VirusTotal waiting limit reached.");
    lastRequest = now();
    requests++;
    const controller = new AbortController();
    let timer;
    try {
      return await Promise.race([
        (async () => {
          const response = await fetchImpl(url, { method, headers: { "x-apikey": key },
            redirect: "error", signal: controller.signal, ...(payload ? { body: payload } : {}) });
          if (response.status >= 300 && response.status < 400)
            throw new ScanError("VirusTotal redirects are refused; no credentials are forwarded.");
          let data;
          try { data = await response.json(); } catch {
            if (response.ok) throw new ScanError("VirusTotal returned invalid JSON.");
          }
          if (!response.ok) {
            const quota = response.status === 429;
            const longQuota = quota && /\b(daily|day|monthly|month)\b/i.test(data?.error?.message ?? "");
            throw new RequestError(response.status, {
              missing: response.status === 404 && data?.error?.code === "NotFoundError",
              transient: !longQuota && (quota || response.status >= 500),
              delay: quota ? retryDelay(response.headers.get("retry-after"), now()) : 2_000,
            });
          }
          return data;
        })(),
        new Promise((_, reject) => {
          timer = setTimeout(() => { controller.abort(); reject(new RequestError(0, { transient: true, delay: 2_000 })); },
            Math.max(1, Math.min(requestTimeoutMs, deadline - now())));
        }),
      ]);
    } catch (error) {
      if (error instanceof ScanError) throw error;
      throw new RequestError(0, { transient: true, delay: 2_000 });
    } finally { clearTimeout(timer); }
  }
  async function request(url, options = {}) {
    for (let attempt = 1; ; attempt++) {
      try { return await once(url, options); } catch (error) {
        if (options.allowMissing && error instanceof RequestError && error.missing) return undefined;
        if (!(error instanceof RequestError) || !error.transient || options.method === "POST" || attempt >= attempts) throw error;
        await wait(Math.max(error.delay, 2_000 * 2 ** (attempt - 1)));
      }
    }
  }
  return { request, wait, now, get requests() { return requests; } };
}

async function scan(file, options = {}) {
  const key = (options.env ?? process.env).VT_API_KEY;
  if (typeof key !== "string" || !key.trim())
    throw new ScanError("VT_API_KEY is not configured. No file was uploaded.");
  const artifact = await publicArtifact(file);
  const client = createClient({ ...options, key });
  const pollMs = Math.max(30_000, options.pollMs ?? 30_000);
  const usedUploadUrls = new Set();
  const reportUrl = `https://www.virustotal.com/gui/file/${artifact.sha256}`;
  let uploaded = false;
  let uploadAttempted = false;
  let analysisId;
  const save = options.onState ?? (async () => {});
  const state = async (status) => save({ sha256: artifact.sha256, status, uploaded,
    ...(uploadAttempted ? { uploadAttempted: true } : {}),
    ...(analysisId ? { analysisId } : {}) });
  const getFile = (allowMissing = false, polling = false) => client.request(`${API}/files/${artifact.sha256}`,
    { allowMissing, ...(polling ? { minimumInterval: pollMs } : {}) });
  async function waitForFile(response, earliestDate = 0) {
    for (;;) {
      const result = fileResult(response, artifact.sha256, client.now());
      if (result && Date.parse(result.analysisDate) >= earliestDate) return result;
      await state("incomplete");
      await client.wait(pollMs);
      response = await getFile(false, true);
    }
  }
  try {
    await state("checking");
    const existing = await getFile(true);
    let result;
    if (existing) {
      result = await waitForFile(existing);
    } else {
      let submission;
      for (let attempt = 1; attempt <= 3; attempt++) {
        let url = `${API}/files`;
        if (artifact.size >= SMALL_FILE) {
          url = trustedUrl((await client.request(`${API}/files/upload_url`))?.data);
          if (usedUploadUrls.has(url)) throw new ScanError("VirusTotal returned an already used upload URL.");
          usedUploadUrls.add(url);
        }
        try {
          uploadAttempted = true;
          await state("uploading");
          submission = await client.request(url, { method: "POST", body: async () => {
            const form = new FormData();
            form.append("file", await fs.openAsBlob(artifact.file), artifact.filename);
            return form;
          } });
          uploaded = true;
          break;
        } catch (error) {
          if (!(error instanceof RequestError) || !error.transient) throw error;
          await client.wait(Math.max(error.delay, 2_000 * 2 ** (attempt - 1)));
          // A timed-out POST may have succeeded. Reconcile by hash before a new submission.
          const recovered = await getFile(true);
          if (recovered) { uploaded = true; result = await waitForFile(recovered); break; }
          if (attempt === 3) throw error;
        }
      }
      if (!result) {
        analysisId = submission?.data?.id;
        if (typeof analysisId !== "string" || !/^[A-Za-z0-9_+=/-]{1,512}$/.test(analysisId))
          throw new ScanError("VirusTotal returned no valid analysis ID.");
        await state("submitted");
        for (;;) {
          await client.wait(pollMs);
          const analysis = await client.request(`${API}/analyses/${encodeURIComponent(analysisId)}`,
            { minimumInterval: pollMs });
          if (analysis?.data?.id !== analysisId ||
              (analysis?.meta?.file_info?.sha256 && analysis.meta.file_info.sha256 !== artifact.sha256))
            throw new ScanError("VirusTotal's analysis does not match this submission.");
          const attributes = analysis.data.attributes;
          if (attributes?.status === "completed") {
            const date = analysisDate(attributes.date, client.now());
            if (!statistics(attributes.stats)) throw new ScanError("Completed analysis contains no engine results.");
            result = await waitForFile(await getFile(), Date.parse(date));
            break;
          }
          if (attributes?.status !== "queued" && attributes?.status !== "in-progress")
            throw new ScanError("VirusTotal returned an unknown analysis status.");
          await state("incomplete");
        }
      }
    }
    if ((await sha256(artifact.file)) !== artifact.sha256)
      throw new ScanError("The final artifact changed during verification; do not publish it.");
    const report = { sha256: artifact.sha256, reportUrl, ...result, status: "completed", uploaded };
    await save(report);
    return report;
  } catch (error) {
    await state("incomplete");
    throw error;
  }
}

async function main(argv = process.argv.slice(2)) {
  if (argv.length !== 3 || argv[1] !== "--output" || !argv[0] || !argv[2])
    throw new ScanError("Usage: node contrib/virustotal.cjs <final-installer-path> --output <report-json-path>");
  const input = await fsp.realpath(argv[0]);
  const output = path.resolve(argv[2]);
  const outputStat = await fsp.lstat(output).catch((error) => {
    if (error.code !== "ENOENT") throw error;
    return undefined;
  });
  const inputStat = await fsp.stat(input);
  if (output === input || outputStat?.isSymbolicLink() ||
      (outputStat && outputStat.dev === inputStat.dev && outputStat.ino === inputStat.ino))
    throw new ScanError("The report output must be separate from the final artifact and must not be a link.");
  await fsp.mkdir(path.dirname(output), { recursive: true });
  const writeState = async (value) => {
    const temporary = `${output}.${randomBytes(8).toString("hex")}.tmp`;
    try {
      await fsp.writeFile(temporary, JSON.stringify(value, null, 2) + "\n", { mode: 0o600, flag: "wx" });
      await fsp.rename(temporary, output);
    } finally { await fsp.unlink(temporary).catch(() => {}); }
  };
  // Invalidate an older successful report before starting a new verification.
  await writeState({ status: "incomplete", uploaded: false });
  const report = await scan(argv[0], { onState: writeState });
  console.log(JSON.stringify(report));
}

module.exports = { ScanError, SMALL_FILE, MAX_FILE, sha256, publicArtifact, trustedUrl,
  statistics, analysisDate, fileResult, retryDelay, createClient, scan, main };
if (require.main === module) main().catch((error) => {
  console.error(error instanceof ScanError ? error.message : "VirusTotal verification failed; no credentials are logged.");
  process.exitCode = 1;
});
