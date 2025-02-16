const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const {getFirestore} = require("firebase-admin/firestore");
const {OpenAI} = require("openai");
const fs = require("fs");
const path = require("path");
const os = require("os");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// Initialize Firebase Admin
initializeApp();

// Initialize Firestore and Storage
const db = getFirestore();

// Function to generate title and description using OpenAI
async function generateTitleAndDescription(subtitles) {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  const functions = [{
    name: "set_video_metadata",
    description: "Set the title and description for a TikTok-style educational video",
    parameters: {
      type: "object",
      properties: {
        title: {
          type: "string",
          description: "Catchy and engaging title for the video (max 50 characters)"
        },
        description: {
          type: "string",
          description: "Brief description of the video content (max 150 characters)"
        }
      },
      required: ["title", "description"]
    }
  }];

  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [{
      role: "user",
      content: `Based on these video subtitles, generate a catchy title and brief description for a TikTok-style educational video:\n\n${subtitles}`
    }],
    functions,
    function_call: { name: "set_video_metadata" },
    temperature: 0.7,
  });

  try {
    const functionCall = completion.choices[0].message.function_call;
    const response = JSON.parse(functionCall.arguments);
    return {
      title: response.title || "",
      description: response.description || ""
    };
  } catch (error) {
    logger.error("Error parsing OpenAI response:", error);
    return {
      title: "",
      description: ""
    };
  }
}

// Cloud function to generate subtitles
exports.generateSubtitles = onDocumentCreated("videos/{videoId}", async (event) => {
  // Create a temporary file path
  const tempFilePath = path.join(os.tmpdir(), `video-${Date.now()}.mp4`);
  
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

    // Download video file
    const response = await fetch(videoUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch video: ${response.statusText}`);
    }

    // Write the video to a temporary file
    const buffer = await response.buffer();
    fs.writeFileSync(tempFilePath, buffer);

    // Create a readable stream from the temporary file
    const videoFile = fs.createReadStream(tempFilePath);

    // Create a transcription using Whisper API
    const transcription = await openai.audio.transcriptions.create({
      file: videoFile,
      model: "whisper-1",
      response_format: "srt",
      language: "en",
    });

    // Generate title and description if title is empty
    let updateData = {
      subtitles: transcription,
      subtitlesGeneratedAt: new Date(),
    };

    if (!videoData.title || videoData.title.trim() === "") {
      logger.info("Generating title and description for video");
      const { title, description } = await generateTitleAndDescription(transcription);
      updateData.title = title;
      updateData.description = description;
    }

    // Update the Firestore document with the subtitles and optional title/description
    await event.data.ref.set(updateData, {merge: true});

    logger.info("Subtitle generation complete for video:", path.basename(videoUrl));

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
  } finally {
    // Clean up: Delete the temporary file
    try {
      if (fs.existsSync(tempFilePath)) {
        fs.unlinkSync(tempFilePath);
        logger.info("Temporary file cleaned up:", tempFilePath);
      }
    } catch (cleanupError) {
      logger.error("Error cleaning up temporary file:", cleanupError);
    }
  }
});
