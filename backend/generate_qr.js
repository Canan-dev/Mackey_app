const QRCode = require('qrcode');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const directApkUrl = 'https://canan-dev.github.io/Mackey_app/';
const logoPath = path.join(__dirname, '../assets/mmc-logo.png');
const outputPngPath = path.join(__dirname, '../../MMC_App_Download_QR.png');
const outputHtmlPath = path.join(__dirname, '../../MMC_App_Download_QR.html');

async function generateBrandedQR() {
  try {
    const qrSize = 800;
    const logoSize = 180;
    const logoPadding = 12;
    const containerSize = logoSize + logoPadding * 2;

    // Remove old file if exists
    try { if (fs.existsSync(outputPngPath)) fs.unlinkSync(outputPngPath); } catch (_) {}

    // 1. Generate High Error Correction (Level H) QR Code Buffer (Blue/White, no dark grey)
    const qrBuffer = await QRCode.toBuffer(directApkUrl, {
      color: {
        dark: '#0052D4',
        light: '#FFFFFF'
      },
      width: qrSize,
      margin: 2,
      errorCorrectionLevel: 'H'
    });

    // 2. Prepare logo: resized
    const logoBuffer = await sharp(logoPath)
      .resize(logoSize, logoSize, { fit: 'contain' })
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
            `<svg><rect x="0" y="0" width="${containerSize}" height="${containerSize}" rx="32" ry="32"/></svg>`
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

    // 5. Generate Data URL for HTML poster (Clean white/transparent theme, NO dark grey)
    const qrDataUrl = `data:image/png;base64,${finalPngBuffer.toString('base64')}`;

    const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Direct Download MMC App</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', -apple-system, system-ui, sans-serif; }
    body {
      background: #f8fafc;
      color: #0f172a;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 24px;
    }
    .card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 32px;
      padding: 40px;
      text-align: center;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.06);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #eff6ff;
      border: 1px solid #bfdbfe;
      color: #1d4ed8;
      padding: 8px 20px;
      border-radius: 30px;
      font-weight: 700;
      font-size: 13px;
      margin-bottom: 20px;
    }
    h1 {
      font-size: 28px;
      font-weight: 800;
      color: #0f172a;
      margin-bottom: 8px;
    }
    p {
      color: #64748b;
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 28px;
    }
    .qr-frame {
      background: #ffffff;
      padding: 16px;
      border-radius: 24px;
      display: inline-block;
      border: 1px solid #e2e8f0;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.04);
      margin-bottom: 28px;
    }
    .qr-frame img {
      display: block;
      width: 280px;
      height: 280px;
      border-radius: 12px;
    }
    .download-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      width: 100%;
      background: linear-gradient(135deg, #00C6FF 0%, #0072FF 100%);
      color: #ffffff;
      text-decoration: none;
      padding: 16px 28px;
      border-radius: 20px;
      font-weight: 800;
      font-size: 16px;
      box-shadow: 0 10px 24px rgba(0, 114, 255, 0.3);
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .download-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 14px 28px rgba(0, 114, 255, 0.4);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">📲 DIRECT APK DOWNLOAD</div>
    <h1>Scan to Download MMC</h1>
    <p>Scan with your phone camera or tap the button below to download <strong>app-release.apk</strong> directly.</p>
    <div class="qr-frame">
      <img src="${qrDataUrl}" alt="MMC App Direct Download QR Code" />
    </div>
    <div>
      <a href="${directApkUrl}app-release.apk" class="download-btn">
        📥 Download app-release.apk
      </a>
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
