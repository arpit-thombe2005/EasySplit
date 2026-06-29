/**
 * fetch_stitch.mjs
 * Downloads all screen assets and Flutter code from Google Stitch
 * for the SplitMate Expense Manager project.
 *
 * Usage: node fetch_stitch.mjs
 */

import { execSync } from 'child_process';
import { mkdirSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = '5036966438345508564';

const SCREENS = [
  { name: 'groups_screen',      id: '53f663ffd7154d8590a0ca7f955b51c4' },
  { name: 'home_dashboard',     id: '474c8dd913074d6fb729187f944f1fc8' },
  { name: 'sign_up_screen',     id: '31ca0e66b7ae4861bcdf63df77afb36c' },
  { name: 'otp_screen',         id: '8b6bfe7a16d341b08c6ee6870e14ea11' },
  { name: 'profile_screen',     id: 'd70531ccc2174905a0e0d6635eeb2f3d' },
  { name: 'email_login',        id: 'a87eb656c38649bb93a2dae92c011eb9' },
  { name: 'add_expense_screen', id: 'b7f6aca0dd2f464ea98e069e4732a2dc' },
  { name: 'design_system',      id: 'asset-stub-assets_e4092969e53b4616a7ecb5c05d1468d5' },
];

// Stitch base URLs to try
const BASE_URLS = [
  `https://stitch.withgoogle.com/api/v1/projects/${PROJECT_ID}`,
  `https://stitch.withgoogle.com/projects/${PROJECT_ID}`,
];

const OUT_DIR = join(__dirname, 'stitch_assets');
mkdirSync(OUT_DIR, { recursive: true });

function curl(url, outFile) {
  try {
    execSync(`curl -L -s -o "${outFile}" "${url}"`, { timeout: 30000 });
    return true;
  } catch {
    return false;
  }
}

function curlJson(url) {
  try {
    const result = execSync(`curl -L -s "${url}"`, { timeout: 30000 });
    return JSON.parse(result.toString());
  } catch {
    return null;
  }
}

console.log('🎨 Fetching Stitch assets for SplitMate Expense Manager...\n');

for (const screen of SCREENS) {
  const screenDir = join(OUT_DIR, screen.name);
  mkdirSync(screenDir, { recursive: true });

  console.log(`📱 Fetching: ${screen.name} (${screen.id})`);

  // Try Flutter code export
  const flutterUrls = [
    `https://stitch.withgoogle.com/api/v1/projects/${PROJECT_ID}/screens/${screen.id}/export/flutter`,
    `https://stitch.withgoogle.com/export/flutter?project=${PROJECT_ID}&screen=${screen.id}`,
  ];

  let fetched = false;
  for (const url of flutterUrls) {
    const data = curlJson(url);
    if (data) {
      writeFileSync(join(screenDir, 'flutter_export.json'), JSON.stringify(data, null, 2));
      console.log(`  ✅ Flutter export saved`);
      fetched = true;
      break;
    }
  }

  // Try image/preview
  const imageUrls = [
    `https://stitch.withgoogle.com/api/v1/projects/${PROJECT_ID}/screens/${screen.id}/preview`,
    `https://stitch.withgoogle.com/preview/${PROJECT_ID}/${screen.id}.png`,
  ];

  for (const url of imageUrls) {
    if (curl(url, join(screenDir, 'preview.png'))) {
      console.log(`  ✅ Preview image saved`);
      break;
    }
  }

  if (!fetched) {
    console.log(`  ⚠️  Could not fetch Flutter export for ${screen.name} — will use design system specs`);
  }
}

console.log('\n✅ Done! Assets saved to: stitch_assets/');
