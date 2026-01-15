import json
import os
import boto3
from typing import Dict, Any
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Get detailed metadata for a photo from DynamoDB.
    Returns complete metadata including both original and edited version info.
    """
    try:
        # Extract user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Get photo ID from path parameters
        photo_id = event['pathParameters']['photo_id']
        
        # Get photo metadata from DynamoDB
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
        
        # Build response with complete metadata
        metadata = {
            'photo_id': photo_metadata['photo_id'],
            'user_id': photo_metadata['user_id'],
            'created_at': photo_metadata.get('created_at'),
            'updated_at': photo_metadata.get('updated_at'),
            'status': photo_metadata.get('status', 'unknown'),
            'original': {
                'filename': photo_metadata.get('filename'),
                'content_type': photo_metadata.get('content_type'),
                'file_size': int(photo_metadata.get('file_size', 0)),
                's3_key': photo_metadata.get('original_s3_key'),
                'bucket': photo_metadata.get('original_bucket')
            }
        }
        
        # Add edited version info if available
        if photo_metadata.get('has_edited_version', False):
            metadata['edited'] = {
                'filename': photo_metadata.get('edited_filename'),
                'content_type': photo_metadata.get('edited_content_type'),
                'file_size': int(photo_metadata.get('edited_file_size', 0)),
                's3_key': photo_metadata.get('edited_s3_key'),
                'bucket': photo_metadata.get('edited_bucket'),
                'edit_count': int(photo_metadata.get('edit_count', 1))
            }
        else:
            metadata['edited'] = None
        
        # Add optional extensible metadata
        optional_fields = ['geolocation', 'tags', 'description', 'camera_info']
        for field in optional_fields:
            if field in photo_metadata:
                metadata[field] = photo_metadata[field]
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(convert_decimals(metadata), default=str)
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

def convert_decimals(obj):
    """Convert Decimal objects to int/float for JSON serialization"""
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj

def get_cors_headers() -> Dict[str, str]:
    """Return CORS headers for API responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
