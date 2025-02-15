/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const {getFirestore} = require("firebase-admin/firestore");
const {OpenAI} = require("openai");
const ffmpeg = require("ffmpeg-static");
const {exec} = require("child_process");
const {promisify} = require("util");
const fs = require("fs");
const path = require("path");
const os = require("os");

const functions = require("firebase-functions");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Initialize Firebase Admin
initializeApp();

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: functions.config().openai.key,
});

// Initialize Firestore
const db = getFirestore();

/**
 * Cloud Function triggered when a video is uploaded to Firebase Storage
 */
exports.generateSubtitles = onObjectFinalized({
  cpu: 2, // Allocate 2 CPU cores
  memory: "2GiB", // Allocate 2GB of memory
  maxInstances: 10, // Maximum number of concurrent instances
  timeoutSeconds: 540, // Maximum execution time (9 minutes)
}, async (event) => {
  // Only process video files
  const contentType = event.data.contentType || "";
  if (!contentType.includes("video/")) {
    console.log("Not a video file, skipping subtitle generation");
    return;
  }

  const fileBucket = event.data.bucket;
  const filePath = event.data.name;
  const fileName = path.basename(filePath);
  const tempFilePath = path.join(os.tmpdir(), fileName);

  try {
    // Download video file
    const bucket = getStorage().bucket(fileBucket);
    await bucket.file(filePath).download({destination: tempFilePath});
    console.log("Video downloaded to:", tempFilePath);

    // Create a transcription using Whisper API
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath),
      model: "whisper-1",
      response_format: "srt",
      language: "en", // You might want to make this dynamic
    });

    // Save the SRT file
    const srtFileName = `${path.parse(fileName).name}.srt`;
    const srtPath = path.join(os.tmpdir(), srtFileName);
    fs.writeFileSync(srtPath, transcription);

    // Upload SRT file to Firebase Storage
    const srtStoragePath = `subtitles/${srtFileName}`;
    await bucket.upload(srtPath, {
      destination: srtStoragePath,
      metadata: {
        contentType: "text/plain",
      },
    });

    // Get the public URL for the SRT file
    const [srtUrl] = await bucket.file(srtStoragePath).getSignedUrl({
      action: "read",
      expires: "03-01-2500", // Far future expiration
    });

    // Update video metadata in Firestore
    const videoId = path.parse(fileName).name;
    await db.collection("videos").doc(videoId).update({
      subtitlesUrl: srtUrl,
      hasSubtitles: true,
      subtitlesLanguage: "en",
      updatedAt: new Date(),
    });

    // Clean up temporary files
    fs.unlinkSync(tempFilePath);
    fs.unlinkSync(srtPath);

    console.log("Subtitle generation complete for:", fileName);
  } catch (error) {
    console.error("Error generating subtitles:", error);
    throw error; // Rethrowing to trigger Cloud Function retry
  }
});
