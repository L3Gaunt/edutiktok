const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {logger} = require("firebase-functions");
const functions = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const {getFirestore} = require("firebase-admin/firestore");
const {OpenAI} = require("openai");
const fs = require("fs");
const path = require("path");
const os = require("os");

// Initialize Firebase Admin
initializeApp();

// Initialize Firestore
const db = getFirestore();

// Cloud function to generate subtitles
exports.generateSubtitles = onObjectFinalized({
  cpu: 2, // Allocate 2 CPU cores
  memory: "2GiB", // Allocate 2GB of memory
  maxInstances: 3, // Maximum number of concurrent instances
  timeoutSeconds: 540, // Maximum execution time (9 minutes)
}, async (event) => {
  try {
    // Only process MP4 video files
    const contentType = event.data.contentType || "";
    if (contentType !== "video/mp4") {
      logger.info("Not an MP4 video file, skipping subtitle generation");
      return;
    }

    logger.info("Generate subtitles triggered for upload:", event.data.name);

    // Initialize OpenAI client inside the function
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    if (!process.env.OPENAI_API_KEY) {
      throw new Error("OpenAI API key not configured. Please set using firebase functions:config:set openai.key=<key>");
    }

    const fileBucket = event.data.bucket;
    const filePath = event.data.name;
    const fileName = path.basename(filePath);
    const tempFilePath = path.join(os.tmpdir(), fileName);

    // Get storage bucket reference
    const bucket = getStorage().bucket(fileBucket);

    // Download video file
    await bucket.file(filePath).download({destination: tempFilePath});
    logger.info("Video downloaded to:", tempFilePath);

    // Create a transcription using Whisper API
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath),
      model: "whisper-1",
      response_format: "srt",
      language: "en", // You might want to make this dynamic
    });

    // Save the SRT file
    const srtFileName = `${fileName}.srt`;
    const srtPath = path.join(os.tmpdir(), srtFileName);
    fs.writeFileSync(srtPath, transcription);

    // Log the subtitle content
    logger.info("Generated subtitles content:");
    logger.info(transcription);

    // Upload SRT file to Firebase Storage in the same path as the video
    const srtStoragePath = `${filePath}.srt`;
    await bucket.upload(srtPath, {
      destination: srtStoragePath,
      metadata: {
        contentType: "text/plain",
      },
    });

    // Get the public download URL for the subtitle file
    const subtitlesUrl = `https://storage.googleapis.com/${fileBucket}/${srtStoragePath}`;

    // Clean up temporary files
    fs.unlinkSync(tempFilePath);
    fs.unlinkSync(srtPath);

    logger.info("Subtitle generation complete for:", fileName);

    return {
      success: true,
      message: "Subtitles generated successfully",
      data: {
        subtitlesPath: subtitlesUrl,
        videoPath: filePath,
      },
    };
  } catch (error) {
    // Log the error
    logger.error("Error generating subtitles:", error);

    // Return error response
    throw new Error(`Failed to generate subtitles: ${error.message}`);
  }
});
