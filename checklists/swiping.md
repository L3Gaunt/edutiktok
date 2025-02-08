# Checklist

Considerations:
[x] Decide on swipe threshold distance for triggering actions (0.3 of screen width)
[x] Determine if we want visual feedback during swipe (e.g., overlay icons/colors) (Yes - with opacity based on swipe progress)

Implementation:
[x] Add GestureDetector with horizontal drag support
[x] Implement swipe animation and reset logic
[x] Create hide/disapprove video functionality (swipe left with red indicator)
[x] Implement video reply picker and upload (swipe right with blue video camera indicator)
[x] Add visual feedback during swipe

Features Added:
- Swipe right to record and upload a video reply
- Video replies are linked to original videos in Firestore
- Reply count tracking for original videos
- Progress indicator during reply upload
- Automatic camera launch for quick replies

Warnings:
- Web image_picker implementation might have different capabilities compared to mobile
- Need to ensure smooth performance while swiping during video playback
- Swipe gestures should not interfere with vertical PageView scrolling
- Test swipe performance on lower-end devices
- Ensure video reply UI matches platform-specific camera interfaces
- Consider adding a reply thread view to see all replies to a video