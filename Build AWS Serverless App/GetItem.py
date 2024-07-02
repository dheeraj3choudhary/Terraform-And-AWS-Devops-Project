import os
import json
import decimal
from botocore.exceptions import ClientError
import boto3

# Get the service resource
dynamodb = boto3.resource('dynamodb')

# Custom JSON encoder to handle Decimal objects
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return str(obj)
        return json.JSONEncoder.default(self, obj)

def handler(event, context):
    try:
        # Retrieve the table name from the environment variable
        table_name = os.environ['TABLE_TABLE_NAME']
        table = dynamodb.Table(table_name)

        # Parse the id from the path parameters
        item_id = event['pathParameters']['id']

        # Retrieve the item from the DynamoDB table using the id as the key
        response = table.get_item(Key={'id': item_id})

        # Check if the item exists
        if 'Item' in response:
            item = response['Item']
            # Return a 200 status code with the item details
            return {
                'statusCode': 200,
                'body': json.dumps(item, cls=DecimalEncoder)
            }
        else:
            # Return a 404 status code with a message if the item is not found
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'Item not found'})
            }

    except ClientError as e:
        # Return a 500 status code with an error message if any exception occurs
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
