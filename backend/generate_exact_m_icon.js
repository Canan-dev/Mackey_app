const sharp = require('./node_modules/sharp');
const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const assetsDir = path.join(projectRoot, 'assets');
const resDir = path.join(projectRoot, 'android/app/src/main/res');
const webIconsDir = path.join(projectRoot, 'web/icons');
const webFaviconPath = path.join(projectRoot, 'web/favicon.png');

const size = 1024;
const svgContent = `
<svg width="${size}" height="${size}" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Background Dark Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1B1E22"/>
      <stop offset="100%" stop-color="#111315"/>
    </linearGradient>

    <!-- 'M' Fluid Cyan/Blue Ribbon Gradient -->
    <linearGradient id="mGrad" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00D2FF"/>
      <stop offset="35%" stop-color="#00A8FF"/>
      <stop offset="70%" stop-color="#0066FF"/>
      <stop offset="100%" stop-color="#0040E0"/>
    </linearGradient>

    <!-- Subtle Drop Shadow -->
    <filter id="mShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000000" flood-opacity="0.6"/>
    </filter>
  </defs>

  <!-- Dark Squircle Background -->
  <rect x="32" y="32" width="960" height="960" rx="220" ry="220" fill="url(#bgGrad)"/>

  <!-- Thick Smooth Ribbon 'M' Symbol -->
  <path d="M 310,710
           L 310,380
           C 310,290 410,280 460,350
           L 512,440
           L 564,350
           C 614,280 714,290 714,380
           L 714,710"
        fill="none"
        stroke="url(#mGrad)"
        stroke-width="128"
        stroke-linecap="round"
        stroke-linejoin="round"
        filter="url(#mShadow)" />
</svg>
`;

async function generateAllAppIcons() {
  console.log('Generating exact M logo matching user screenshot...');

  if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });
  if (!fs.existsSync(webIconsDir)) fs.mkdirSync(webIconsDir, { recursive: true });

  const svgBuffer = Buffer.from(svgContent);

  // Master PNG & JPG
  const masterPngPath = path.join(assetsDir, 'mmc-logo.png');
  const masterJpgPath = path.join(assetsDir, 'mmc-logo.jpg');

  await sharp(svgBuffer).resize(1024, 1024).png().toFile(masterPngPath);
  await sharp(svgBuffer).resize(1024, 1024).jpeg({ quality: 95 }).toFile(masterJpgPath);

  // Android Launcher Icons
  const androidDensities = [
    { dir: 'mipmap-mdpi', size: 48 },
    { dir: 'mipmap-hdpi', size: 72 },
    { dir: 'mipmap-xhdpi', size: 96 },
    { dir: 'mipmap-xxhdpi', size: 144 },
    { dir: 'mipmap-xxxhdpi', size: 192 },
  ];

  for (const item of androidDensities) {
    const targetDir = path.join(resDir, item.dir);
    if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });
    await sharp(svgBuffer).resize(item.size, item.size).png().toFile(path.join(targetDir, 'ic_launcher.png'));
  }

  // Web PWA Icons & Favicon
  await sharp(svgBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-192.png'));
  await sharp(svgBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-512.png'));
  await sharp(svgBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-maskable-192.png'));
  await sharp(svgBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-maskable-512.png'));
  await sharp(svgBuffer).resize(64, 64).png().toFile(webFaviconPath);

  console.log('Exact M icon successfully generated across all densities!');
}

generateAllAppIcons().catch(console.error);
