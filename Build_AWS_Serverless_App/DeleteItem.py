import os
import json
from botocore.exceptions import ClientError
import boto3

# Get the service resource
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    try:
        # Retrieve the table name from the environment variable
        table_name = os.environ['TABLE_TABLE_NAME']
        table = dynamodb.Table(table_name)

        # Parse the id from the path parameters
        item_id = event['pathParameters']['id']

        # Delete the item from the DynamoDB table using the id as the key
        response = table.delete_item(Key={'id': item_id})

        # Check if the item was deleted successfully
        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
            # Return a 200 status code with a message if the item is deleted successfully
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Item deleted successfully'})
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
