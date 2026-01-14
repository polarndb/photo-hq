import json
import os
import boto3
from typing import Dict, Any
from boto3.dynamodb.conditions import Key

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Generate presigned URL for downloading photos from S3.
    Supports both original and edited versions.
    
    Query parameters:
    - version: 'original' or 'edited' (default: 'original')
    """
    try:
        # Extract user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Get photo ID from path parameters
        photo_id = event['pathParameters']['photo_id']
        
        # Get version type from query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        version_type = query_params.get('version', 'original')
        
        if version_type not in ['original', 'edited']:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'version must be either "original" or "edited"'})
            }
        
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
        
        # Determine which S3 key and bucket to use
        if version_type == 'original':
            s3_key = photo_metadata.get('original_s3_key')
            bucket = photo_metadata.get('original_bucket')
        else:
            # Check if edited version exists
            if not photo_metadata.get('has_edited_version', False):
                return {
                    'statusCode': 404,
                    'headers': get_cors_headers(),
                    'body': json.dumps({'error': 'No edited version available'})
                }
            s3_key = photo_metadata.get('edited_s3_key')
            bucket = photo_metadata.get('edited_bucket')
        
        if not s3_key or not bucket:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': f'{version_type.capitalize()} version not found'})
            }
        
        # Generate presigned URL for download (valid for 15 minutes)
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket,
                'Key': s3_key,
            },
            ExpiresIn=900
        )
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'photo_id': photo_id,
                'version_type': version_type,
                'download_url': presigned_url,
                'expires_in': 900,
                'metadata': {
                    'filename': photo_metadata.get('filename'),
                    'content_type': photo_metadata.get('content_type'),
                    'file_size': photo_metadata.get('file_size'),
                    'created_at': photo_metadata.get('created_at'),
                    'updated_at': photo_metadata.get('updated_at')
                }
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
