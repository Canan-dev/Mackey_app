const sharp = require('./node_modules/sharp');
const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const assetsDir = path.join(projectRoot, 'assets');
const resDir = path.join(projectRoot, 'android/app/src/main/res');
const webIconsDir = path.join(projectRoot, 'web/icons');
const webFaviconPath = path.join(projectRoot, 'web/favicon.png');

// Create master 1024x1024 SVG for MMC App Icon with original Electric Cyan Blue theme
const size = 1024;
const svgContent = `
<svg width="${size}" height="${size}" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Background Gradient -->
    <radialGradient id="bgGradient" cx="50%" cy="35%" r="65%" fx="50%" fy="25%">
      <stop offset="0%" stop-color="#1D2630"/>
      <stop offset="60%" stop-color="#11161B"/>
      <stop offset="100%" stop-color="#0B0E12"/>
    </radialGradient>

    <!-- Original Cyan/Sky Blue Brand Gradient -->
    <linearGradient id="cyanGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#70E5FF"/>
      <stop offset="45%" stop-color="#00DAFD"/>
      <stop offset="100%" stop-color="#0088CC"/>
    </linearGradient>

    <!-- Glowing Accent Gradient -->
    <linearGradient id="glowGradient" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00DAFD"/>
      <stop offset="100%" stop-color="#00E5FF"/>
    </linearGradient>

    <!-- Glow & Shadow Filters -->
    <filter id="cyanGlow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="16" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>

    <filter id="dropShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#000000" flood-opacity="0.65"/>
    </filter>
  </defs>

  <!-- Squircle Base (Modern, Smooth, Non-Triangular) -->
  <rect x="32" y="32" width="960" height="960" rx="220" ry="220" fill="url(#bgGradient)"/>

  <!-- Outer Cyan Accent Border -->
  <rect x="48" y="48" width="928" height="928" rx="204" ry="204"
        fill="none" stroke="url(#cyanGradient)" stroke-width="8" opacity="0.45" />

  <!-- Inner Soft Glow Frame -->
  <rect x="64" y="64" width="896" height="896" rx="188" ry="188"
        fill="none" stroke="#00DAFD" stroke-width="2" opacity="0.2" />

  <!-- Center Dual Chat/Connection Bubbles in Original Cyan Blue -->
  <g filter="url(#dropShadow)">
    <!-- Primary Chat Badge -->
    <rect x="292" y="260" width="440" height="320" rx="90" ry="90"
          fill="url(#cyanGradient)" opacity="0.95" />

    <!-- Secondary Offset Chat Badge -->
    <rect x="392" y="440" width="340" height="240" rx="70" ry="70"
          fill="#151D24" stroke="url(#cyanGradient)" stroke-width="8" />

    <!-- Chat Dots in Secondary Bubble -->
    <circle cx="482" cy="560" r="18" fill="#00DAFD" />
    <circle cx="562" cy="560" r="18" fill="#00DAFD" />
    <circle cx="642" cy="560" r="18" fill="#00DAFD" />
  </g>

  <!-- MMC Bold Stylized Typography -->
  <g filter="url(#dropShadow)" text-anchor="middle">
    <text x="512" y="480"
          font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif"
          font-weight="900"
          font-size="160"
          letter-spacing="12"
          fill="#0B0E12">MMC</text>
  </g>

  <!-- Bottom Accent Status Pillar -->
  <rect x="452" y="760" width="120" height="12" rx="6" ry="6" fill="url(#cyanGradient)" />
</svg>
`;

async function generateAllAppIcons() {
  console.log('Generating high-resolution MMC app icon in original Cyan/Blue colors...');

  if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });
  if (!fs.existsSync(webIconsDir)) fs.mkdirSync(webIconsDir, { recursive: true });

  const svgBuffer = Buffer.from(svgContent);

  // 1. Generate 1024x1024 Master PNG and JPG in assets
  const masterPngPath = path.join(assetsDir, 'mmc-logo.png');
  const masterJpgPath = path.join(assetsDir, 'mmc-logo.jpg');

  await sharp(svgBuffer).resize(1024, 1024).png().toFile(masterPngPath);
  await sharp(svgBuffer).resize(1024, 1024).jpeg({ quality: 95 }).toFile(masterJpgPath);
  console.log('Master assets generated: mmc-logo.png, mmc-logo.jpg');

  // 2. Android Density Icon Sizes
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

    const targetPath = path.join(targetDir, 'ic_launcher.png');
    await sharp(svgBuffer).resize(item.size, item.size).png().toFile(targetPath);
    console.log(`Android icon generated: ${item.dir}/ic_launcher.png (${item.size}x${item.size})`);
  }

  // 3. Web PWA Icons & Favicon
  await sharp(svgBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-192.png'));
  await sharp(svgBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-512.png'));
  await sharp(svgBuffer).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-maskable-192.png'));
  await sharp(svgBuffer).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-maskable-512.png'));
  await sharp(svgBuffer).resize(64, 64).png().toFile(webFaviconPath);
  console.log('Web PWA icons and favicon generated.');

  console.log('All icons successfully updated in original Electric Cyan Blue!');
}

generateAllAppIcons().catch(console.error);
