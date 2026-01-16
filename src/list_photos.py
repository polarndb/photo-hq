import json
import os
import boto3
from typing import Dict, Any, List
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['PHOTOS_TABLE'])

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    List user's photos with optional filtering.
    
    Query parameters:
    - version_type: 'original' or 'edited' (optional, returns all if not specified)
    - limit: number of items to return (default: 50, max: 100)
    - last_evaluated_key: for pagination (returned from previous request)
    """
    try:
        # Extract user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        version_type = query_params.get('version_type')
        limit = min(int(query_params.get('limit', 50)), 100)
        last_key = query_params.get('last_evaluated_key')
        
        # Validate version_type if provided
        if version_type and version_type not in ['original', 'edited']:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'version_type must be either "original" or "edited"'})
            }
        
        # Query DynamoDB using GSI
        query_params_db = {
            'IndexName': 'UserVersionIndex' if version_type else 'UserIdIndex',
            'KeyConditionExpression': Key('user_id').eq(user_id),
            'Limit': limit,
            'ScanIndexForward': False  # Most recent first
        }
        
        # Add version_type filter if specified
        if version_type:
            query_params_db['KeyConditionExpression'] = (
                Key('user_id').eq(user_id) & Key('version_type').eq(version_type)
            )
        
        # Add pagination token if provided
        if last_key:
            try:
                query_params_db['ExclusiveStartKey'] = json.loads(last_key)
            except:
                return {
                    'statusCode': 400,
                    'headers': get_cors_headers(),
                    'body': json.dumps({'error': 'Invalid pagination token'})
                }
        
        # Execute query
        response = table.query(**query_params_db)
        
        # Process items
        photos = []
        for item in response.get('Items', []):
            photo = {
                'photo_id': item['photo_id'],
                'filename': item.get('filename'),
                'version_type': item.get('version_type'),
                'content_type': item.get('content_type'),
                'file_size': int(item.get('file_size', 0)),
                'created_at': item.get('created_at'),
                'updated_at': item.get('updated_at'),
                'has_edited_version': item.get('has_edited_version', False),
                'status': item.get('status', 'unknown')
            }
            
            # Include optional metadata if available
            if item.get('geolocation'):
                photo['geolocation'] = item['geolocation']
            if item.get('tags'):
                photo['tags'] = item['tags']
            
            photos.append(photo)
        
        # Prepare response
        result = {
            'photos': photos,
            'count': len(photos),
            'scanned_count': response.get('ScannedCount', 0)
        }
        
        # Add pagination token if there are more results
        if 'LastEvaluatedKey' in response:
            result['last_evaluated_key'] = json.dumps(
                convert_decimals(response['LastEvaluatedKey'])
            )
            result['has_more'] = True
        else:
            result['has_more'] = False
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result, default=str)
        }
        
    except KeyError as e:
        return {
            'statusCode': 401,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': f'Authentication required: {str(e)}'})
        }
    except ValueError as e:
        return {
            'statusCode': 400,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': f'Invalid parameter: {str(e)}'})
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
