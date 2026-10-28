const sharp = require('./node_modules/sharp');
const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const assetsDir = path.join(projectRoot, 'assets');
const resDir = path.join(projectRoot, 'android/app/src/main/res');
const webIconsDir = path.join(projectRoot, 'web/icons');
const webFaviconPath = path.join(projectRoot, 'web/favicon.png');

const size = 1024;

// 1. Transparent SVG for PNG assets (No dark background box)
const svgTransparentContent = `
<svg width="${size}" height="${size}" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- 'M' Fluid Cyan/Blue Ribbon Gradient -->
    <linearGradient id="mGrad" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00D2FF"/>
      <stop offset="35%" stop-color="#00A8FF"/>
      <stop offset="70%" stop-color="#0066FF"/>
      <stop offset="100%" stop-color="#0040E0"/>
    </linearGradient>

    <filter id="mShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#0066FF" flood-opacity="0.3"/>
    </filter>
  </defs>

  <!-- Thick Smooth Ribbon 'M' Symbol (Transparent Background) -->
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

// 2. Solid SVG for JPG assets
const svgJpgContent = `
<svg width="${size}" height="${size}" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="mGrad" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00D2FF"/>
      <stop offset="35%" stop-color="#00A8FF"/>
      <stop offset="70%" stop-color="#0066FF"/>
      <stop offset="100%" stop-color="#0040E0"/>
    </linearGradient>

    <filter id="mShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000000" flood-opacity="0.2"/>
    </filter>
  </defs>

  <rect width="${size}" height="${size}" fill="#FFFFFF"/>

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
  console.log('Generating transparent M logo assets without dark background...');

  if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });
  if (!fs.existsSync(webIconsDir)) fs.mkdirSync(webIconsDir, { recursive: true });

  const transparentBuffer = Buffer.from(svgTransparentContent);
  const jpgBuffer = Buffer.from(svgJpgContent);

  // Master PNG (Transparent background) & JPG
  const masterPngPath = path.join(assetsDir, 'mmc-logo.png');
  const masterJpgPath = path.join(assetsDir, 'mmc-logo.jpg');

  await sharp(transparentBuffer).resize(1024, 1024).png().toFile(masterPngPath);
  await sharp(jpgBuffer).resize(1024, 1024).jpeg({ quality: 95 }).toFile(masterJpgPath);

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
    await sharp(transparentBuffer).resize(item.size, item.size).png().toFile(path.join(targetDir, 'ic_launcher.png'));
  }

  // Web PWA Icons & Favicon
  await sharp(transparentBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-192.png'));
  await sharp(transparentBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-512.png'));
  await sharp(transparentBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-maskable-192.png'));
  await sharp(transparentBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-maskable-512.png'));
  await sharp(transparentBuffer).resize(64, 64).png().toFile(webFaviconPath);

  console.log('Transparent M logo successfully created without dark grey background!');
}

generateAllAppIcons().catch(console.error);
