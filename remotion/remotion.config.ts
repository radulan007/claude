import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Config } from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
Config.setEntryPoint("src/index.ts");

// Remotion normally downloads its own Chrome Headless Shell. Where that download
// is blocked (sandboxes, CI behind a proxy), reuse one that is already installed:
// $REMOTION_BROWSER_EXECUTABLE, then HyperFrames' cached copy, then Playwright's.
const findHeadlessShell = (): string | null => {
  if (process.env.REMOTION_BROWSER_EXECUTABLE) return process.env.REMOTION_BROWSER_EXECUTABLE;
  const roots = [
    join(homedir(), ".cache/hyperframes/chrome/chrome-headless-shell"),
    process.env.PLAYWRIGHT_BROWSERS_PATH ?? "/opt/pw-browsers",
  ];
  for (const root of roots) {
    if (!existsSync(root)) continue;
    for (const dir of readdirSync(root).sort().reverse()) {
      for (const sub of ["chrome-headless-shell-linux64", "chrome-linux64", "chrome-linux"]) {
        const bin = join(root, dir, sub, "chrome-headless-shell");
        if (existsSync(bin)) return bin;
      }
    }
  }
  return null;
};

const browser = findHeadlessShell();
if (browser) Config.setBrowserExecutable(browser);
