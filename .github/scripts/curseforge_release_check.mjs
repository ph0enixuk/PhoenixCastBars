import fs from "node:fs";
import path from "node:path";

const CURSEFORGE_API_KEY = process.env.CURSEFORGE_API_KEY?.trim();
const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL?.trim();
const CURSEFORGE_PROJECT_ID = process.env.CURSEFORGE_PROJECT_ID?.trim();
const DISCORD_ROLE_ID = process.env.DISCORD_ROLE_ID?.trim();
const ADDON_DISPLAY_NAME = process.env.ADDON_DISPLAY_NAME?.trim() || "Addon";

if (!CURSEFORGE_API_KEY) throw new Error("Missing env: CURSEFORGE_API_KEY");
if (!DISCORD_WEBHOOK_URL) throw new Error("Missing env: DISCORD_WEBHOOK_URL");
if (!CURSEFORGE_PROJECT_ID) throw new Error("Missing env: CURSEFORGE_PROJECT_ID");

const statePath = path.resolve(".github/curseforge-state.json");

function readState() {
  try {
    const raw = fs.readFileSync(statePath, "utf8");
    const json = JSON.parse(raw);
    return { lastFileId: Number(json.lastFileId) || 0 };
  } catch {
    return { lastFileId: 0 };
  }
}

function writeState(lastFileId) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  fs.writeFileSync(statePath, JSON.stringify({ lastFileId }, null, 2) + "\n", "utf8");
}

async function cfGetJson(url) {
  const r = await fetch(url, {
    headers: {
      "Accept": "application/json",
      "x-api-key": CURSEFORGE_API_KEY,
    },
  });
  if (!r.ok) {
    const text = await r.text().catch(() => "");
    throw new Error(`CurseForge API ${r.status} ${r.statusText}: ${text}`);
  }
  return r.json();
}

function pickNewestFile(files) {
  // Defensive: choose newest by fileDate, not by array order.
  let newest = null;
  let newestTime = -Infinity;

  for (const f of files) {
    const t = Date.parse(f.fileDate);
    if (!Number.isFinite(t)) continue;
    if (t > newestTime) {
      newestTime = t;
      newest = f;
    }
  }
  return newest;
}

function formatReleaseType(releaseType) {
  // CurseForge uses numeric releaseType; wording varies by client.
  // Common convention: 1=Release, 2=Beta, 3=Alpha.
  switch (Number(releaseType)) {
    case 1: return "Release";
    case 2: return "Beta";
    case 3: return "Alpha";
    default: return `Type ${releaseType}`;
  }
}

async function postDiscord(payload) {
  const r = await fetch(DISCORD_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!r.ok) {
    const text = await r.text().catch(() => "");
    throw new Error(`Discord webhook ${r.status} ${r.statusText}: ${text}`);
  }
}

async function main() {
  const state = readState();

  // Get mod metadata (for website URL)
  const mod = await cfGetJson(`https://api.curseforge.com/v1/mods/${encodeURIComponent(CURSEFORGE_PROJECT_ID)}`);
  const websiteUrl = mod?.data?.links?.websiteUrl || null;

  // Get latest files (pageSize max is 50)
  const filesResp = await cfGetJson(
    `https://api.curseforge.com/v1/mods/${encodeURIComponent(CURSEFORGE_PROJECT_ID)}/files?pageSize=50&index=0`
  );

  const files = Array.isArray(filesResp?.data) ? filesResp.data : [];
  if (!files.length) {
    console.log("No files returned by CurseForge API; exiting.");
    return;
  }

  const newest = pickNewestFile(files);
  if (!newest) {
    console.log("Could not determine newest file; exiting.");
    return;
  }

  const newestId = Number(newest.id);
  if (!Number.isFinite(newestId)) throw new Error("Newest file has invalid id");

  console.log(`Last posted fileId: ${state.lastFileId}`);
  console.log(`Newest fileId: ${newestId} (${newest.displayName})`);

  if (newestId === state.lastFileId) {
    console.log("No new release detected.");
    return;
  }

  // Build a clean Discord message
  const mention = DISCORD_ROLE_ID ? `<@&${DISCORD_ROLE_ID}> ` : "";
  const title = `${ADDON_DISPLAY_NAME} updated: ${newest.displayName}`;
  const releaseType = formatReleaseType(newest.releaseType);

  const gameVersions = Array.isArray(newest.gameVersions) ? newest.gameVersions : [];
  const gameVersionsText =
    gameVersions.length ? gameVersions.slice(0, 12).join(", ") + (gameVersions.length > 12 ? "…" : "") : "—";

  const projectLink = websiteUrl || "https://www.curseforge.com/";

  const embed = {
    title,
    url: projectLink,
    fields: [
      { name: "Release Type", value: releaseType, inline: true },
      { name: "File ID", value: String(newestId), inline: true },
      { name: "Published", value: newest.fileDate || "—", inline: false },
      { name: "Game Versions", value: gameVersionsText, inline: false },
    ],
    footer: { text: "Automated release ping (CurseForge)" },
  };

  await postDiscord({
    content: `${mention}**${ADDON_DISPLAY_NAME}** has a new CurseForge file.`,
    embeds: [embed],
    allowed_mentions: {
      // Prevent accidental @everyone/@here; allow only the opted-in role mention.
      parse: [],
      roles: DISCORD_ROLE_ID ? [DISCORD_ROLE_ID] : [],
    },
  });

  // Persist the new file ID to prevent duplicates
  writeState(newestId);
  console.log("Posted to Discord and updated state.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
