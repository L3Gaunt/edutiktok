# My History Feature Implementation Checklist

## Considerations
- [x] Decide on the query strategy for fetching view history:
  - Use the "views" collection filtered by userId.
  - When filtering for liked videos, determine whether to perform a client-side intersection with the "likes" collection or to modify the query.
- [x] Confirm how to handle videos viewed multiple times (e.g., deduplication of entries versus showing each view).
- [x] Determine if pagination is needed when the view history list grows large.
- [x] Finalize the UI design for the filtering control (checkbox versus switch) and its placement on the screen.
- [x] Review if additional Firestore indexes are required for optimal performance when filtering by timestamp and userId.

## Tasks
- [x] Create a new screen file "lib/screens/my_history_screen.dart" to display the user's video view history.
- [x] Implement a Firestore query in "MyHistoryScreen" to fetch documents from the "views" collection where the "userId" equals the current user's uid, sorted by the "timestamp" field (newest first).
- [x] Build a UI list to display the viewed videos, including relevant metadata (e.g., video title, thumbnail, view date).
- [x] Add a toggle control (checkbox or switch) on "MyHistoryScreen" labeled "Only show liked videos."
- [x] When the toggle is active, adjust the query or perform client-side filtering to display only videos that the user has liked (by checking against the "likes" collection).
- [x] If necessary, update or create service methods in the LikeService and/or ViewService to support querying liked status for a list of videos.
- [x] Update the bottom navigation bar in the main Hub (e.g., in "HomePage" or "main.dart") to include the new "My History" destination between "Feed" and "Upload."
- [x] Include the "My History" screen in the IndexedStack (or equivalent navigation structure) to ensure smooth modality switching.
- [x] Update routing configuration if using named routes to integrate the new screen.
- [x] Add error handling and loading states within "MyHistoryScreen" for network issues or empty query results.
- [x] Write tests (unit and integration) to verify that:
  - The view history loads correctly.
  - The filter toggle properly restricts the list to liked videos.
  - Navigation between "Feed", "My History", and "Upload" works as expected.

## Warnings
- [x] Ensure Firestore query performance by checking if additional indexes are needed for filtering by "userId" and "timestamp."
- [x] Validate that UI adjustments for the additional navigation destination do not disrupt the existing user flow.
- [x] Confirm that the new functionalities adhere to existing Firestore security rules.
- [x] Test the behavior across different devices and network conditions to ensure a consistent user experience.