const QRCode = require('qrcode');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const directApkUrl = 'https://pro2007-bot.github.io/Mackey_app/';
const logoPath = path.join(__dirname, '../assets/mmc-logo.jpg');
const outputPngPath = path.join(__dirname, '../../MMC_App_Download_QR.png');
const outputHtmlPath = path.join(__dirname, '../../MMC_App_Download_QR.html');

async function generateBrandedQR() {
  try {
    const qrSize = 800;
    const logoSize = 160;
    const logoPadding = 12;
    const containerSize = logoSize + logoPadding * 2;

    // Remove old file if exists
    try { if (fs.existsSync(outputPngPath)) fs.unlinkSync(outputPngPath); } catch (_) {}

    // 1. Generate High Error Correction (Level H) QR Code Buffer pointing directly to the APK file
    const qrBuffer = await QRCode.toBuffer(directApkUrl, {
      color: {
        dark: '#111315',
        light: '#FFFFFF'
      },
      width: qrSize,
      margin: 2,
      errorCorrectionLevel: 'H'
    });

    // 2. Prepare logo: resized with rounded corners
    const logoBuffer = await sharp(logoPath)
      .resize(logoSize, logoSize, { fit: 'cover' })
      .composite([
        {
          input: Buffer.from(
            `<svg><rect x="0" y="0" width="${logoSize}" height="${logoSize}" rx="24" ry="24"/></svg>`
          ),
          blend: 'dest-in'
        }
      ])
      .png()
      .toBuffer();

    // 3. Create white background badge for logo center
    const logoBadge = await sharp({
      create: {
        width: containerSize,
        height: containerSize,
        channels: 4,
        background: { r: 255, g: 255, b: 255, alpha: 1 }
      }
    })
      .composite([
        {
          input: Buffer.from(
            `<svg><rect x="0" y="0" width="${containerSize}" height="${containerSize}" rx="28" ry="28"/></svg>`
          ),
          blend: 'dest-in'
        },
        {
          input: logoBuffer,
          top: logoPadding,
          left: logoPadding
        }
      ])
      .png()
      .toBuffer();

    // 4. Composite badge over QR code center
    const finalPngBuffer = await sharp(qrBuffer)
      .composite([
        {
          input: logoBadge,
          top: Math.round((qrSize - containerSize) / 2),
          left: Math.round((qrSize - containerSize) / 2)
        }
      ])
      .png()
      .toBuffer();

    fs.writeFileSync(outputPngPath, finalPngBuffer);
    console.log('Branded Direct Download QR Code PNG saved to:', outputPngPath);

    // 5. Generate Data URL for HTML poster
    const qrDataUrl = `data:image/png;base64,${finalPngBuffer.toString('base64')}`;

    const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Direct Download MMC App</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
    body {
      background: #111315;
      color: #ffffff;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }
    .card {
      background: #1f2427;
      border: 1px solid rgba(255,255,255,0.12);
      border-radius: 28px;
      padding: 40px;
      text-align: center;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 20px 50px rgba(0,0,0,0.6);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: rgba(213, 242, 106, 0.15);
      border: 1px solid #d5f26a;
      color: #d5f26a;
      padding: 8px 20px;
      border-radius: 30px;
      font-weight: 700;
      font-size: 14px;
      margin-bottom: 20px;
    }
    h1 {
      font-size: 28px;
      font-weight: 800;
      margin-bottom: 8px;
    }
    p {
      color: #969b9a;
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 24px;
    }
    .qr-frame {
      background: #ffffff;
      padding: 16px;
      border-radius: 24px;
      display: inline-block;
      box-shadow: 0 12px 30px rgba(0,0,0,0.35);
      margin-bottom: 24px;
    }
    .qr-frame img {
      display: block;
      width: 280px;
      height: 280px;
      border-radius: 8px;
    }
    .instructions {
      background: rgba(255,255,255,0.05);
      border-radius: 16px;
      padding: 16px;
      font-size: 13px;
      color: #e0e0e0;
    }
    .instructions a {
      display: inline-block;
      margin-top: 10px;
      background: #d5f26a;
      color: #111315;
      text-decoration: none;
      padding: 10px 20px;
      border-radius: 20px;
      font-weight: 700;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">📲 DIRECT APK DOWNLOAD</div>
    <h1>Scan to Download MMC</h1>
    <p>Scan with your phone camera to start downloading <strong>app-release.apk</strong> directly onto your phone.</p>
    <div class="qr-frame">
      <img src="${qrDataUrl}" alt="MMC App Direct Download QR Code" />
    </div>
    <div class="instructions">
      Instant Direct Download
      <br/>
      <a href="${directApkUrl}" target="_blank">Download app-release.apk</a>
    </div>
  </div>
</body>
</html>`;

    fs.writeFileSync(outputHtmlPath, htmlContent);
    console.log('HTML QR poster saved to:', outputHtmlPath);
  } catch (err) {
    console.error('Error generating branded QR code:', err);
  }
}

generateBrandedQR();
