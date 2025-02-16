const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const {getFirestore} = require("firebase-admin/firestore");
const {OpenAI} = require("openai");
const fs = require("fs");
const path = require("path");
const os = require("os");

// Initialize Firebase Admin
initializeApp();

// Initialize Firestore and Storage
const db = getFirestore();
// Cloud function to generate subtitles
exports.generateSubtitles = onDocumentCreated("videos/{videoId}", async (event) => {
  try {
    const videoData = event.data.data();
    const videoUrl = videoData.url;

    if (!videoUrl) {
      throw new Error("No video URL found in document");
    }

    logger.info("Generate subtitles triggered for video:", videoUrl);

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    if (!process.env.OPENAI_API_KEY) {
      throw new Error("OpenAI API key not configured. Please set using firebase functions:config:set openai.key=<key>");
    }

    // Download video file to temp location
    const videoFileName = path.basename(videoUrl);
    // Fetch the video and stream it directly to OpenAI
    const response = await fetch(videoUrl);
    
    // Create a transcription using Whisper API by streaming the response
    const transcription = await openai.audio.transcriptions.create({
      file: response.body,
      model: "whisper-1", 
      response_format: "srt",
      language: "en",
    });

    // Update the Firestore document with the subtitles
    await event.data.ref.set({
      subtitles: transcription,
      subtitlesGeneratedAt: new Date(),
    }, {merge: true});

    logger.info("Subtitle generation complete for video:", videoFileName);

    return {
      success: true,
      message: "Subtitles generated and stored in document successfully",
    };
  } catch (error) {
    // Log the error
    logger.error("Error generating subtitles:", error);

    try {
      // Update document with error status
      await event.data.ref.set({
        subtitlesError: error.message,
        subtitlesErrorAt: new Date(),
      }, {merge: true});
    } catch (dbError) {
      logger.error("Failed to update error status in document:", dbError);
    }

    // Return error response
    throw new Error(`Failed to generate subtitles: ${error.message}`);
  }
});
