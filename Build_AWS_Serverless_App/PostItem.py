import os
import json
import decimal
from decimal import Decimal
import boto3

# Get the DynamoDB table name from environment variable
TABLE_NAME = os.environ.get('TABLE_TABLE_NAME')

# Create a DynamoDB client
dynamodb = boto3.client('dynamodb')

def handler(event, context):
    try:
        # Parse the item id from the path parameters
        item_id = event['pathParameters']['id']
        
        # Parse the item details from the request body
        item_details = json.loads(event['body'])
        item_name = item_details['name']
        item_price = Decimal(str(item_details['price']))
        item_category = item_details['category']
        
        # Create the DynamoDB item
        item = {
            'id': {'S': item_id},
            'name': {'S': item_name},
            'price': {'N': str(item_price)},
            'category': {'S': item_category}
        }
        
        # Put the item into the DynamoDB table
        response = dynamodb.put_item(
            TableName=TABLE_NAME,
            Item=item
        )
        
        # Check if the item was created or updated
        if response.get('Attributes'):
            status_code = 200  # Item updated
        else:
            status_code = 201  # Item created
        
        return {
            'statusCode': status_code,
            'body': json.dumps('Item added/updated successfully')
        }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
