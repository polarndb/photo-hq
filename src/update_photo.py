import json
import os
import boto3
from datetime import datetime
from typing import Dict, Any

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])
edited_bucket = os.environ['EDITED_BUCKET']

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Generate presigned URL for uploading edited version of a photo.
    Replaces previous edited version if exists.
    
    Expected input:
    {
        "filename": "photo_edited.jpg",
        "content_type": "image/jpeg",
        "file_size": 1024000
    }
    """
    try:
        # Extract user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Get photo ID from path parameters
        photo_id = event['pathParameters']['photo_id']
        
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
        
        # Get original photo metadata from DynamoDB
        response = table.get_item(Key={'photo_id': photo_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Photo not found'})
            }
        
        photo_metadata = response['Item']
        
        # Verify ownership
        if photo_metadata['user_id'] != user_id:
            return {
                'statusCode': 403,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Access denied'})
            }
        
        timestamp = datetime.utcnow().isoformat()
        
        # S3 key structure: {user_id}/edited/{photo_id}/{filename}
        # This will overwrite any previous edited version
        s3_key = f"{user_id}/edited/{photo_id}/{filename}"
        
        # Get previous edited version info if exists
        previous_edited_key = photo_metadata.get('edited_s3_key')
        
        # Generate presigned URL for upload (valid for 15 minutes)
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': edited_bucket,
                'Key': s3_key,
                'ContentType': content_type,
            },
            ExpiresIn=900
        )
        
        # Update metadata in DynamoDB
        update_expression = (
            "SET edited_s3_key = :s3_key, "
            "edited_bucket = :bucket, "
            "has_edited_version = :has_edited, "
            "updated_at = :timestamp, "
            "edited_filename = :filename, "
            "edited_content_type = :content_type, "
            "edited_file_size = :file_size"
        )
        
        expression_values = {
            ':s3_key': s3_key,
            ':bucket': edited_bucket,
            ':has_edited': True,
            ':timestamp': timestamp,
            ':filename': filename,
            ':content_type': content_type,
            ':file_size': file_size
        }
        
        # Add version tracking
        if previous_edited_key:
            update_expression += ", edit_count = if_not_exists(edit_count, :zero) + :one"
            expression_values[':zero'] = 0
            expression_values[':one'] = 1
        else:
            update_expression += ", edit_count = :one"
            expression_values[':one'] = 1
        
        table.update_item(
            Key={'photo_id': photo_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values
        )
        
        response_body = {
            'photo_id': photo_id,
            'upload_url': presigned_url,
            'upload_method': 'PUT',
            'expires_in': 900,
            's3_key': s3_key,
            'message': 'Upload the edited file using the provided presigned URL'
        }
        
        if previous_edited_key:
            response_body['note'] = 'This will replace the previous edited version'
            response_body['previous_version'] = previous_edited_key
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(response_body)
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
