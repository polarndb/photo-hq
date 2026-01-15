# Photo HQ API Specification

Version: 1.0.0  
Base URL: `https://{api-id}.execute-api.{region}.amazonaws.com/prod`

## Authentication

All API endpoints require JWT authentication via AWS Cognito.

**Header**:
```
Authorization: Bearer <jwt-token>
```

**Obtaining JWT Token**:
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <UserPoolClientId> \
  --auth-parameters USERNAME=<email>,PASSWORD=<password>
```

Response includes:
- `AccessToken`: Use for API authorization
- `IdToken`: User identity claims
- `RefreshToken`: Obtain new tokens

## Endpoints

### 1. Upload Photo

Generate presigned URL for uploading original photo to S3.

**Endpoint**: `POST /photos/upload`

**Headers**:
```
Authorization: Bearer <jwt-token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "filename": "vacation.jpg",
  "content_type": "image/jpeg",
  "file_size": 8388608
}
```

**Parameters**:
- `filename` (required, string): Original filename
- `content_type` (required, string): Must be "image/jpeg" or "image/jpg"
- `file_size` (required, number): File size in bytes (5MB-20MB)

**Success Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "upload_url": "https://photo-hq-originals-123456.s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-abc123/originals/photo-id/vacation.jpg",
  "message": "Upload the file using the provided presigned URL"
}
```

**Error Responses**:

400 Bad Request:
```json
{
  "error": "filename is required"
}
```

400 Bad Request:
```json
{
  "error": "File size must be between 5MB and 20MB"
}
```

400 Bad Request:
```json
{
  "error": "Only JPEG files are supported"
}
```

401 Unauthorized:
```json
{
  "error": "Authentication required"
}
```

**Usage Example**:
```bash
# Step 1: Get presigned URL
RESPONSE=$(curl -X POST https://api-endpoint/prod/photos/upload \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "photo.jpg",
    "content_type": "image/jpeg",
    "file_size": 10485760
  }')

UPLOAD_URL=$(echo $RESPONSE | jq -r '.upload_url')
PHOTO_ID=$(echo $RESPONSE | jq -r '.photo_id')

# Step 2: Upload file to S3
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --upload-file photo.jpg
```

---

### 2. Get Photo

Generate presigned URL for downloading photo from S3.

**Endpoint**: `GET /photos/{photo_id}`

**Headers**:
```
Authorization: Bearer <jwt-token>
```

**Path Parameters**:
- `photo_id` (required, UUID): Photo identifier

**Query Parameters**:
- `version` (optional, string): "original" or "edited" (default: "original")

**Success Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "version_type": "original",
  "download_url": "https://photo-hq-originals-123456.s3.amazonaws.com/...",
  "expires_in": 900,
  "metadata": {
    "filename": "vacation.jpg",
    "content_type": "image/jpeg",
    "file_size": 8388608,
    "created_at": "2024-01-14T10:30:00.000Z",
    "updated_at": "2024-01-14T10:30:00.000Z"
  }
}
```

**Error Responses**:

400 Bad Request:
```json
{
  "error": "version must be either \"original\" or \"edited\""
}
```

403 Forbidden:
```json
{
  "error": "Access denied"
}
```

404 Not Found:
```json
{
  "error": "Photo not found"
}
```

404 Not Found:
```json
{
  "error": "No edited version available"
}
```

**Usage Example**:
```bash
# Get original version
curl -X GET "https://api-endpoint/prod/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Get edited version
curl -X GET "https://api-endpoint/prod/photos/$PHOTO_ID?version=edited" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Download photo
DOWNLOAD_URL=$(curl -s -X GET "https://api-endpoint/prod/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $JWT_TOKEN" | jq -r '.download_url')

curl -o photo.jpg "$DOWNLOAD_URL"
```

---

### 3. List Photos

List user's photos with optional filtering and pagination.

**Endpoint**: `GET /photos`

**Headers**:
```
Authorization: Bearer <jwt-token>
```

**Query Parameters**:
- `version_type` (optional, string): Filter by "original" or "edited"
- `limit` (optional, number): Items per page (1-100, default: 50)
- `last_evaluated_key` (optional, string): Pagination token from previous response

**Success Response** (200 OK):
```json
{
  "photos": [
    {
      "photo_id": "123e4567-e89b-12d3-a456-426614174000",
      "filename": "vacation.jpg",
      "version_type": "original",
      "content_type": "image/jpeg",
      "file_size": 8388608,
      "created_at": "2024-01-14T10:30:00.000Z",
      "updated_at": "2024-01-14T10:30:00.000Z",
      "has_edited_version": true,
      "status": "uploaded",
      "tags": ["vacation", "beach"],
      "geolocation": {
        "latitude": 40.7128,
        "longitude": -74.0060
      }
    },
    {
      "photo_id": "223e4567-e89b-12d3-a456-426614174001",
      "filename": "sunset.jpg",
      "version_type": "original",
      "content_type": "image/jpeg",
      "file_size": 9437184,
      "created_at": "2024-01-13T15:20:00.000Z",
      "updated_at": "2024-01-13T15:20:00.000Z",
      "has_edited_version": false,
      "status": "uploaded"
    }
  ],
  "count": 2,
  "scanned_count": 2,
  "has_more": false
}
```

**With Pagination**:
```json
{
  "photos": [...],
  "count": 50,
  "scanned_count": 50,
  "has_more": true,
  "last_evaluated_key": "{\"photo_id\":\"...\",\"user_id\":\"...\",\"created_at\":\"...\"}"
}
```

**Error Responses**:

400 Bad Request:
```json
{
  "error": "version_type must be either \"original\" or \"edited\""
}
```

400 Bad Request:
```json
{
  "error": "Invalid pagination token"
}
```

**Usage Example**:
```bash
# List all photos
curl -X GET "https://api-endpoint/prod/photos" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Filter by original photos only, limit to 20
curl -X GET "https://api-endpoint/prod/photos?version_type=original&limit=20" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Get next page
curl -X GET "https://api-endpoint/prod/photos?last_evaluated_key=$PAGINATION_TOKEN" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

### 4. Update Photo (Upload Edited Version)

Generate presigned URL for uploading edited version of a photo.

**Endpoint**: `PUT /photos/{photo_id}/edit`

**Headers**:
```
Authorization: Bearer <jwt-token>
Content-Type: application/json
```

**Path Parameters**:
- `photo_id` (required, UUID): Photo identifier

**Request Body**:
```json
{
  "filename": "vacation_edited.jpg",
  "content_type": "image/jpeg",
  "file_size": 7340032
}
```

**Parameters**:
- `filename` (required, string): Edited filename
- `content_type` (required, string): Must be "image/jpeg" or "image/jpg"
- `file_size` (required, number): File size in bytes (5MB-20MB)

**Success Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "upload_url": "https://photo-hq-edited-123456.s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-abc123/edited/photo-id/vacation_edited.jpg",
  "message": "Upload the edited file using the provided presigned URL",
  "note": "This will replace the previous edited version",
  "previous_version": "user-abc123/edited/photo-id/vacation_v1.jpg"
}
```

**First Edit Response** (without previous_version):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "upload_url": "https://photo-hq-edited-123456.s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-abc123/edited/photo-id/vacation_edited.jpg",
  "message": "Upload the edited file using the provided presigned URL"
}
```

**Error Responses**:

400 Bad Request:
```json
{
  "error": "filename is required"
}
```

403 Forbidden:
```json
{
  "error": "Access denied"
}
```

404 Not Found:
```json
{
  "error": "Photo not found"
}
```

**Usage Example**:
```bash
# Step 1: Get presigned URL for edited version
RESPONSE=$(curl -X PUT "https://api-endpoint/prod/photos/$PHOTO_ID/edit" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "photo_edited.jpg",
    "content_type": "image/jpeg",
    "file_size": 9437184
  }')

UPLOAD_URL=$(echo $RESPONSE | jq -r '.upload_url')

# Step 2: Upload edited file to S3
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --upload-file photo_edited.jpg
```

---

### 5. Delete Photo

Delete photo and all versions (original and edited) from storage.

**Endpoint**: `DELETE /photos/{photo_id}`

**Headers**:
```
Authorization: Bearer <jwt-token>
```

**Path Parameters**:
- `photo_id` (required, UUID): Photo identifier

**Success Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Photo and all versions deleted successfully",
  "deleted_items": [
    {
      "type": "original",
      "bucket": "photo-hq-originals-123456",
      "key": "user-abc123/originals/photo-id/vacation.jpg"
    },
    {
      "type": "edited",
      "bucket": "photo-hq-edited-123456",
      "key": "user-abc123/edited/photo-id/vacation_edited.jpg"
    }
  ]
}
```

**Success Response (No Edited Version)**:
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Photo and all versions deleted successfully",
  "deleted_items": [
    {
      "type": "original",
      "bucket": "photo-hq-originals-123456",
      "key": "user-abc123/originals/photo-id/vacation.jpg"
    }
  ]
}
```

**Error Responses**:

403 Forbidden:
```json
{
  "error": "Access denied"
}
```

404 Not Found:
```json
{
  "error": "Photo not found"
}
```

**Usage Example**:
```bash
curl -X DELETE "https://api-endpoint/prod/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

### 6. Get Photo Metadata

Get complete metadata for a photo including version information.

**Endpoint**: `GET /photos/{photo_id}/metadata`

**Headers**:
```
Authorization: Bearer <jwt-token>
```

**Path Parameters**:
- `photo_id` (required, UUID): Photo identifier

**Success Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "cognito-user-sub-abc123",
  "created_at": "2024-01-14T10:30:00.000Z",
  "updated_at": "2024-01-14T11:45:00.000Z",
  "status": "uploaded",
  "original": {
    "filename": "vacation.jpg",
    "content_type": "image/jpeg",
    "file_size": 8388608,
    "s3_key": "user-abc123/originals/photo-id/vacation.jpg",
    "bucket": "photo-hq-originals-123456"
  },
  "edited": {
    "filename": "vacation_edited.jpg",
    "content_type": "image/jpeg",
    "file_size": 7340032,
    "s3_key": "user-abc123/edited/photo-id/vacation_edited.jpg",
    "bucket": "photo-hq-edited-123456",
    "edit_count": 2
  },
  "tags": ["vacation", "beach", "sunset"],
  "geolocation": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "description": "Beautiful sunset at the beach"
}
```

**Response (No Edited Version)**:
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "cognito-user-sub-abc123",
  "created_at": "2024-01-14T10:30:00.000Z",
  "updated_at": "2024-01-14T10:30:00.000Z",
  "status": "uploaded",
  "original": {
    "filename": "sunset.jpg",
    "content_type": "image/jpeg",
    "file_size": 9437184,
    "s3_key": "user-abc123/originals/photo-id/sunset.jpg",
    "bucket": "photo-hq-originals-123456"
  },
  "edited": null
}
```

**Error Responses**:

403 Forbidden:
```json
{
  "error": "Access denied"
}
```

404 Not Found:
```json
{
  "error": "Photo not found"
}
```

**Usage Example**:
```bash
curl -X GET "https://api-endpoint/prod/photos/$PHOTO_ID/metadata" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

## Data Models

### Photo Metadata Schema

```typescript
interface PhotoMetadata {
  // Primary identifiers
  photo_id: string;          // UUID
  user_id: string;           // Cognito user sub
  
  // Timestamps
  created_at: string;        // ISO 8601
  updated_at: string;        // ISO 8601
  
  // Status
  status: "pending_upload" | "uploaded" | "processing" | "error";
  
  // Original version
  filename: string;
  original_s3_key: string;
  original_bucket: string;
  content_type: string;
  file_size: number;         // bytes
  version_type: "original" | "edited";
  
  // Edited version (optional)
  has_edited_version: boolean;
  edited_filename?: string;
  edited_s3_key?: string;
  edited_bucket?: string;
  edited_content_type?: string;
  edited_file_size?: number;
  edit_count?: number;       // Number of times edited
  
  // Extensible metadata (optional)
  tags?: string[];
  geolocation?: {
    latitude: number;
    longitude: number;
  };
  description?: string;
  camera_info?: {
    make?: string;
    model?: string;
    iso?: number;
    aperture?: string;
    shutter_speed?: string;
  };
}
```

### Error Response Schema

```typescript
interface ErrorResponse {
  error: string;             // Human-readable error message
}
```

---

## HTTP Status Codes

- **200 OK**: Request succeeded
- **400 Bad Request**: Invalid input parameters
- **401 Unauthorized**: Missing or invalid authentication
- **403 Forbidden**: User doesn't have permission
- **404 Not Found**: Resource doesn't exist
- **500 Internal Server Error**: Server-side error

---

## Rate Limits

Currently no hard rate limits enforced. API Gateway default throttling:
- **Burst limit**: 5000 requests
- **Steady-state**: 10000 requests per second per region

For production, consider implementing:
- Per-user rate limiting
- Usage plans with API keys
- Exponential backoff on client side

---

## CORS Configuration

API supports cross-origin requests with the following headers:

**Allowed Origins**: `*` (configure to specific domains in production)  
**Allowed Methods**: `GET, POST, PUT, DELETE, OPTIONS`  
**Allowed Headers**: `Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token`  
**Max Age**: 600 seconds

---

## Pagination

List endpoints support cursor-based pagination:

1. Initial request returns up to `limit` items
2. If more items exist, response includes `last_evaluated_key`
3. Use `last_evaluated_key` in next request to get next page
4. Continue until `has_more` is `false`

**Example Flow**:
```bash
# Page 1
RESPONSE=$(curl -X GET "https://api-endpoint/prod/photos?limit=50" \
  -H "Authorization: Bearer $JWT_TOKEN")

NEXT_KEY=$(echo $RESPONSE | jq -r '.last_evaluated_key')

# Page 2
curl -X GET "https://api-endpoint/prod/photos?limit=50&last_evaluated_key=$NEXT_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

## Best Practices

### Client Implementation

1. **Handle Presigned URLs**:
   - Use presigned URLs immediately
   - URLs expire after 15 minutes
   - Request new URL if expired

2. **Upload/Download**:
   - Use HTTP PUT for uploads (not POST)
   - Set correct Content-Type header
   - Handle network interruptions with retry logic

3. **Error Handling**:
   - Implement exponential backoff for 5xx errors
   - Validate inputs client-side before API calls
   - Handle 403 errors gracefully

4. **Token Management**:
   - Store tokens securely
   - Refresh before expiration
   - Clear tokens on logout

### Security

1. **Never expose tokens in URLs or logs**
2. **Validate file types client-side**
3. **Use HTTPS only**
4. **Implement CSRF protection in web apps**
5. **Sanitize user inputs**

### Performance

1. **Implement client-side caching**
2. **Use pagination for large lists**
3. **Compress images before upload**
4. **Parallel uploads for batch operations**

---

## Versioning

Current API Version: **v1**

API versioning strategy:
- Breaking changes: New version (v2, v3, etc.)
- Non-breaking changes: Same version with deprecation notices
- Deprecated endpoints: 6-month sunset period

---

## Support

For API issues:
1. Check CloudWatch logs for error details
2. Verify authentication tokens
3. Review request/response in browser DevTools
4. Contact support with request ID from error response

---

## Change Log

### Version 1.0.0 (2024-01-14)
- Initial API release
- Complete CRUD operations
- Cognito authentication
- Photo version management
- Presigned URL generation
- Metadata tracking with extensible schema
