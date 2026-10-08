// Browser-side media optimization for the ApniPost admin upload pipeline.
//
// Videos are re-encoded to H.264/AAC MP4 (short side <= 720px, <= 30 fps,
// ~2 Mbps, fast-start) with WebCodecs via the vendored Mediabunny library.
// Images are resized (short side <= 1080px) and re-encoded with a canvas.
// GIFs are left untouched (a canvas would drop the animation).
//
// Exposed to Dart as `globalThis.apniMedia.optimize(bytes, mime, onProgress)`,
// resolving to `{ bytes: Uint8Array, mime: string, changed: boolean }`.

const VIDEO_MAX_SHORT_SIDE = 720;
const VIDEO_MAX_FPS = 30;
const VIDEO_BITRATE = 2_000_000;
const AUDIO_BITRATE = 128_000;

const IMAGE_MAX_SHORT_SIDE = 1080;
const IMAGE_QUALITY = 0.85;

let mediabunnyPromise;
function loadMediabunny() {
  mediabunnyPromise ??= import('./vendor/mediabunny/mediabunny.min.js');
  return mediabunnyPromise;
}

function even(n) {
  return Math.max(2, Math.round(n / 2) * 2);
}

function unchanged(bytes, mime) {
  return { bytes, mime, changed: false };
}

async function optimizeVideo(bytes, mime, onProgress) {
  const mb = await loadMediabunny();

  if (!(await mb.canEncodeVideo('avc'))) {
    throw new Error(
      'This browser cannot encode H.264 video. Use the latest Chrome or Edge.',
    );
  }

  const input = new mb.Input({
    source: new mb.BlobSource(new Blob([bytes], { type: mime })),
    formats: mb.ALL_FORMATS,
  });

  try {
    const videoTrack = await input.getPrimaryVideoTrack();
    if (!videoTrack) throw new Error('No video track found in this file.');

    const width = await videoTrack.getDisplayWidth();
    const height = await videoTrack.getDisplayHeight();
    const stats = await videoTrack.computePacketStats(120);
    const fps = stats.averagePacketRate;

    const shortSide = Math.min(width, height);
    const scale = Math.min(1, VIDEO_MAX_SHORT_SIDE / shortSide);
    const needsResize = scale < 1;
    const needsFps = fps > VIDEO_MAX_FPS + 1;
    const needsBitrate = stats.averageBitrate > VIDEO_BITRATE * 1.25;

    if (mime === 'video/mp4' && !needsResize && !needsFps && !needsBitrate) {
      return unchanged(bytes, mime);
    }

    const audioTrack = await input.getPrimaryAudioTrack();
    if (audioTrack && !(await mb.canEncodeAudio('aac'))) {
      throw new Error(
        'This browser cannot encode AAC audio. Use the latest Chrome or Edge.',
      );
    }

    const target = new mb.BufferTarget();
    const output = new mb.Output({
      format: new mb.Mp4OutputFormat({ fastStart: 'in-memory' }),
      target,
    });

    const video = {
      codec: 'avc',
      bitrate: VIDEO_BITRATE,
      forceTranscode: true,
    };
    if (needsResize) {
      video.width = even(width * scale);
      video.height = even(height * scale);
      video.fit = 'fill';
    }
    if (needsFps) video.frameRate = VIDEO_MAX_FPS;

    const conversion = await mb.Conversion.init({
      input,
      output,
      video,
      audio: { codec: 'aac', bitrate: AUDIO_BITRATE },
    });

    if (!conversion.isValid) {
      const reasons = conversion.discardedTracks
        .map((t) => `${t.track.type}: ${t.reason}`)
        .join(', ');
      throw new Error(`Cannot convert this video (${reasons}).`);
    }

    if (onProgress) conversion.onProgress = (p) => onProgress(p);
    await conversion.execute();

    const out = new Uint8Array(target.buffer);
    // Already-small MP4s can come out larger; keep the original then.
    if (mime === 'video/mp4' && out.byteLength >= bytes.byteLength) {
      return unchanged(bytes, mime);
    }
    return { bytes: out, mime: 'video/mp4', changed: true };
  } finally {
    input.dispose();
  }
}

async function optimizeImage(bytes, mime) {
  const bitmap = await createImageBitmap(new Blob([bytes], { type: mime }));
  try {
    const scale = Math.min(
      1,
      IMAGE_MAX_SHORT_SIDE / Math.min(bitmap.width, bitmap.height),
    );
    const w = Math.round(bitmap.width * scale);
    const h = Math.round(bitmap.height * scale);

    const canvas = new OffscreenCanvas(w, h);
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bitmap, 0, 0, w, h);

    // Keep the format: PNG may carry transparency, and WebP/JPEG stay as-is
    // so WhatsApp treats them like normal photos.
    const blob = await canvas.convertToBlob(
      mime === 'image/png' ? { type: mime } : { type: mime, quality: IMAGE_QUALITY },
    );
    const out = new Uint8Array(await blob.arrayBuffer());
    if (out.byteLength >= bytes.byteLength) return unchanged(bytes, mime);
    return { bytes: out, mime, changed: true };
  } finally {
    bitmap.close();
  }
}

async function optimize(bytes, mime, onProgress) {
  if (mime.startsWith('video/')) return optimizeVideo(bytes, mime, onProgress);
  if (mime === 'image/gif' || !mime.startsWith('image/')) {
    return unchanged(bytes, mime);
  }
  return optimizeImage(bytes, mime);
}

globalThis.apniMedia = { optimize };
