import json
import os
import boto3
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])
originals_bucket = os.environ['ORIGINALS_BUCKET']

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Generate presigned URL for uploading photos to S3 originals bucket.
    
    Expected input:
    {
        "filename": "photo.jpg",
        "content_type": "image/jpeg",
        "file_size": 1024000
    }
    """
    try:
        # Extract user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename')
        content_type = body.get('content_type', 'image/jpeg')
        file_size = body.get('file_size', 0)
        
        # Validation
        if not filename:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'filename is required'})
            }
        
        # Validate file size (5-20MB)
        if file_size < 5 * 1024 * 1024 or file_size > 20 * 1024 * 1024:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'File size must be between 5MB and 20MB'})
            }
        
        # Validate content type
        allowed_types = ['image/jpeg', 'image/jpg']
        if content_type.lower() not in allowed_types:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Only JPEG files are supported'})
            }
        
        # Generate unique photo ID
        photo_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        # S3 key structure: {user_id}/originals/{photo_id}/{filename}
        s3_key = f"{user_id}/originals/{photo_id}/{filename}"
        
        # Generate presigned URL for upload (valid for 15 minutes)
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': originals_bucket,
                'Key': s3_key,
                'ContentType': content_type,
            },
            ExpiresIn=900
        )
        
        # Store metadata in DynamoDB
        metadata = {
            'photo_id': photo_id,
            'user_id': user_id,
            'filename': filename,
            'original_s3_key': s3_key,
            'original_bucket': originals_bucket,
            'version_type': 'original',
            'content_type': content_type,
            'file_size': file_size,
            'created_at': timestamp,
            'updated_at': timestamp,
            'has_edited_version': False,
            'status': 'pending_upload'
        }
        
        table.put_item(Item=metadata)
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'photo_id': photo_id,
                'upload_url': presigned_url,
                'upload_method': 'PUT',
                'expires_in': 900,
                's3_key': s3_key,
                'message': 'Upload the file using the provided presigned URL'
            })
        }
        
    except KeyError as e:
        return {
            'statusCode': 401,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': f'Authentication required: {str(e)}'})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_cors_headers() -> Dict[str, str]:
    """Return CORS headers for API responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
