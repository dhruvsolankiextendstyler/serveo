import assert from "assert";
import { detectImageSignature, MAX_IMAGE_SIZE } from "./utils/image_storage.js";

console.log("--- Testing Magic Bytes Image Detection ---");

// 1. JPEG signature: FF D8 FF
const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]);
const jpegResult = detectImageSignature(jpegBuffer);
assert.strictEqual(jpegResult?.mime, "image/jpeg", "JPEG should be detected");
assert.strictEqual(jpegResult?.ext, "jpg");
console.log("✔ JPEG detection passed");

// 2. PNG signature: 89 50 4E 47 0D 0A 1A 0A
const pngBuffer = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d]);
const pngResult = detectImageSignature(pngBuffer);
assert.strictEqual(pngResult?.mime, "image/png", "PNG should be detected");
assert.strictEqual(pngResult?.ext, "png");
console.log("✔ PNG detection passed");

// 3. GIF signature: GIF89a
const gifBuffer = Buffer.from("GIF89a\x01\x00\x01\x00\x80\x00", "binary");
const gifResult = detectImageSignature(gifBuffer);
assert.strictEqual(gifResult?.mime, "image/gif", "GIF should be detected");
assert.strictEqual(gifResult?.ext, "gif");
console.log("✔ GIF detection passed");

// 4. WebP signature: RIFF....WEBP
const webpBuffer = Buffer.from("RIFF\x20\x00\x00\x00WEBPVP8 \x14\x00\x00\x00", "binary");
const webpResult = detectImageSignature(webpBuffer);
assert.strictEqual(webpResult?.mime, "image/webp", "WebP should be detected");
assert.strictEqual(webpResult?.ext, "webp");
console.log("✔ WebP detection passed");

// 5. BMP signature: BM
const bmpBuffer = Buffer.from("BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00", "binary");
const bmpResult = detectImageSignature(bmpBuffer);
assert.strictEqual(bmpResult?.mime, "image/bmp", "BMP should be detected");
assert.strictEqual(bmpResult?.ext, "bmp");
console.log("✔ BMP detection passed");

// 6. HEIC signature: ....ftypheic
const heicBuffer = Buffer.from("\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic", "binary");
const heicResult = detectImageSignature(heicBuffer);
assert.strictEqual(heicResult?.mime, "image/heic", "HEIC should be detected");
assert.strictEqual(heicResult?.ext, "heic");
console.log("✔ HEIC detection passed");

// 7. Text or PDF file (invalid image)
const textBuffer = Buffer.from("Hello world this is a text file not an image!", "utf8");
const textResult = detectImageSignature(textBuffer);
assert.strictEqual(textResult, null, "Text file should be rejected");
console.log("✔ Invalid format rejection passed");

// 8. Size limit
assert.strictEqual(MAX_IMAGE_SIZE, 5 * 1024 * 1024, "Max size should be 5MB");
console.log("✔ Max size limit verified");

console.log("All Backend Image Detection Tests Passed Successfully!");
