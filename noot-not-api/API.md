# API Documentation

## Base URL

`http://localhost:8000/api`

## Endpoints

### 1. Create Confession

**POST** `/confessions`

Creates a new anonymous confession. Content is automatically moderated before being approved.

**Request Body:**

```json
{
  "content": "Your anonymous confession here..."
}
```

**Response (201 Created):**

```json
{
  "message": "Confesión creada exitosamente",
  "confession": {
    "id": "uuid",
    "content": "Your anonymous confession here...",
    "moderation_status": "approved",
    "upvotes": 0,
    "downvotes": 0,
    "reports": 0,
    "image_urls": ["/images/confessions/uuid.png"],
    "created_at": "2025-07-08 12:00:00",
    "updated_at": "2025-07-08 12:00:00"
  }
}
```

**Error Response (400 Bad Request):**

```json
{
  "error": "Contenido rechazado por moderación",
  "reason": "Contiene información personal"
}
```

### 2. List Confessions

**GET** `/confessions`

Retrieves a paginated list of approved confessions.

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20, max: 50)
- `sort` (optional): Sort by `created_at` or `upvotes` (default: `created_at`)

**Response (200 OK):**

```json
{
  "confessions": [
    {
      "id": "uuid",
      "content": "Confession content...",
      "moderation_status": "approved",
      "upvotes": 5,
      "downvotes": 1,
      "reports": 0,
      "image_urls": ["/images/confessions/uuid.png"],
      "created_at": "2025-07-08 12:00:00",
      "updated_at": "2025-07-08 12:00:00"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_items": 100,
    "items_per_page": 20
  }
}
```

### 3. Vote on Confession

**POST** `/confessions/{id}/vote`

Submit an upvote or downvote for a confession.

**Request Body:**

```json
{
  "type": "upvote"
}
```

or

```json
{
  "type": "downvote"
}
```

**Response (200 OK):**

```json
{
  "message": "Vote recorded successfully",
  "confession": {
    "id": "uuid",
    "content": "Confession content...",
    "moderation_status": "approved",
    "upvotes": 6,
    "downvotes": 1,
    "reports": 0,
    "created_at": "2025-07-08 12:00:00",
    "updated_at": "2025-07-08 12:00:00"
  }
}
```

### 4. Report Confession

**POST** `/confessions/{id}/report`

Report a confession for inappropriate content.

**Request Body:** (empty)

**Response (200 OK):**

```json
{
  "message": "Report recorded successfully"
}
```

## Error Codes

- `400` - Bad Request (invalid input, content rejected by moderation)
- `404` - Not Found (confession doesn't exist)
- `500` - Internal Server Error

## Content Moderation

All confessions are automatically moderated using OpenAI's GPT-3.5-turbo model. Content is rejected if it contains:

1. Personal information (emails, phone numbers, addresses)
2. Extremely hateful or threatening language
3. Spam or promotional content
4. Content that could harm someone

If the OpenAI API is unavailable, a fallback basic moderation system is used.

## Image Generation

When a confession is approved, the system automatically generates image(s) with the confession text:

### Features:

- **Background**: 1920x1920 pixel canvas with gradient background or custom image
- **Text Styling**: White text with black outline and shadow for readability
- **ID Display**: Confession ID shown in top-right corner
- **Multi-page Support**: Long confessions are split across multiple images
- **Naming Convention**:
  - Single image: `{confession-id}.png`
  - Multiple images: `{confession-id}-{page-number}.png`

### Technical Details:

- Images are stored in `/public/images/confessions/`
- Maximum ~25 lines per image
- Automatic text wrapping
- Font size: 48px with 60px line height
- Text margins: 100px from edges

### Image URLs:

The `image_urls` field in confession responses contains an array of relative URLs to the generated images.
