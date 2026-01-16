import json
import os
import boto3
from typing import Dict, Any

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Delete photo and associated metadata.
    Removes both original and edited versions from S3 and DynamoDB entry.
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
        
        deleted_items = []
        
        # Delete original from S3
        original_s3_key = photo_metadata.get('original_s3_key')
        original_bucket = photo_metadata.get('original_bucket')
        
        if original_s3_key and original_bucket:
            try:
                s3_client.delete_object(
                    Bucket=original_bucket,
                    Key=original_s3_key
                )
                deleted_items.append({
                    'type': 'original',
                    'bucket': original_bucket,
                    'key': original_s3_key
                })
            except Exception as e:
                print(f"Error deleting original from S3: {str(e)}")
        
        # Delete edited version from S3 if exists
        if photo_metadata.get('has_edited_version', False):
            edited_s3_key = photo_metadata.get('edited_s3_key')
            edited_bucket = photo_metadata.get('edited_bucket')
            
            if edited_s3_key and edited_bucket:
                try:
                    s3_client.delete_object(
                        Bucket=edited_bucket,
                        Key=edited_s3_key
                    )
                    deleted_items.append({
                        'type': 'edited',
                        'bucket': edited_bucket,
                        'key': edited_s3_key
                    })
                except Exception as e:
                    print(f"Error deleting edited version from S3: {str(e)}")
        
        # Delete metadata from DynamoDB
        table.delete_item(Key={'photo_id': photo_id})
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'photo_id': photo_id,
                'message': 'Photo and all versions deleted successfully',
                'deleted_items': deleted_items
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
