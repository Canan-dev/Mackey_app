const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const logoPath = path.join(__dirname, '../assets/mmc-logo.jpg');
const webIconsDir = path.join(__dirname, '../web/icons');
const faviconPath = path.join(__dirname, '../web/favicon.png');

async function generateIcons() {
  if (!fs.existsSync(webIconsDir)) {
    fs.mkdirSync(webIconsDir, { recursive: true });
  }

  await sharp(logoPath).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-192.png'));
  await sharp(logoPath).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-512.png'));
  await sharp(logoPath).resize(192, 192).png().toFile(path.join(webIconsDir, 'Icon-maskable-192.png'));
  await sharp(logoPath).resize(512, 512).png().toFile(path.join(webIconsDir, 'Icon-maskable-512.png'));
  await sharp(logoPath).resize(64, 64).png().toFile(faviconPath);

  console.log('PWA Web Icons successfully generated from mmc-logo.jpg!');
}

generateIcons().catch(console.error);
