# getVideoRecommendations Function Documentation

## Input Parameters

The function expects a request object with the following required parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| videoId | string | The ID of the current video to exclude from recommendations |
| description | string | The description of the current video used to find relevant recommendations |

## Return Value

The function returns an object with the following structure:

| Field | Type | Description |
|-------|------|-------------|
| recommendations | array | Array of recommended video objects |

Each video object in the recommendations array contains:

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique identifier of the video |
| title | string | Title of the video |
| description | string | Description of the video content |
| url | string | URL to access the video |
| likes | number | Number of likes on the video |
| views | number | Number of views on the video |
| timestamp | timestamp | When the video was created/uploaded |
| userId | string | ID of the user who uploaded the video |
| subtitles | string | Video subtitles (if available) |

## Error Handling

The function will throw an error if:
- `videoId` or `description` parameters are missing
- There's an internal error during recommendation generation 