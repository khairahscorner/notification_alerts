import os
import boto3
import json
from datetime import datetime


def send_to_sns(message):
    sns_topic_arn = os.getenv('SNS_TOPIC_ARN')
    sns_client = boto3.client("sns")
  
  # Publish to SNS
    print(f"Publishing to SNS topic: {sns_topic_arn}")
    try:
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=message,
            Subject="Weather Updates"
        )
        print("Message published to SNS successfully.")
    except Exception as e:
        print(f"Error publishing to SNS: {e}")
        return {"statusCode": 500, "body": "Error publishing to SNS"}
    
    return {"statusCode": 200, "body": "Data processed and sent to SNS"}

  

def lambda_handler(event, context):
    region = os.environ['AWS_REGION']
    s3_client = boto3.client('s3', region_name=region)
    bucket_name = os.getenv('BUCKET_NAME')

    try:
        # Check if the bucket exists
        print(f"Checking if bucket {bucket_name} exists")
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"Bucket {bucket_name} exists")
    except:
        print(f"bucket {bucket_name} does not exist, cannot fetch data")
        return
  
    try:
        # Get the most recently added object in the bucket
        response = s3_client.list_objects_v2(Bucket=bucket_name)

        print(f"Bucket '{bucket_name}' is empty.")

        # Sort objects by LastModified in descending order
        objects = sorted(response['Contents'], key=lambda obj: obj['LastModified'], reverse=True)
        most_recent_object = objects[0]
        key = most_recent_object['Key']

        # Retrieve the object
        obj = s3_client.get_object(Bucket=bucket_name, Key=key)
        body = obj['Body'].read().decode('utf-8')

        # Check if the file is JSON
        try:
            json_data = json.loads(body)
            print(f"Successfully retrieved the JSON object from '{key}' in bucket '{bucket_name}'.")
        except json.JSONDecodeError:
            print(f"The most recent file '{key}' in bucket '{bucket_name}' is not a valid JSON file.")
            return

    except Exception as e:
        print('Could not run function successfully')
        return

    city = json_data.get("name", "N/A")
    main_desc = json_data.get("weather", [{}])[0].get("main", "N/A")
    description = json_data.get("weather", [{}])[0].get("description", "N/A")
    temp = json_data.get("main", {}).get("temp", "N/A")
    humidity = json_data.get("main", {}).get("humidity", "N/A")
    wind_speed = json_data.get("wind", {}).get("speed", "N/A")
    day = datetime.strptime(json_data.get("timestamp", "N/A"), "%d%m%Y-%H%M%S")

    message = (
            f"New weather data uploaded to the weather dashboard app storage!\n\n\n"
            f"Data retrieved for {city}, recorded at {day}\n\n"
            f"-> {main_desc}: {description}\n"
            f"-> Temperature: {temp} °F\n"
            f"-> Humidity: {humidity}\n"
            f"-> Wind Speed: {wind_speed}\n"
    )

    send_to_sns(message)
