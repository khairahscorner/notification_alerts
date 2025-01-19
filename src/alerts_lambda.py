import os
import json
import urllib.parse
import urllib.request
import boto3
from datetime import datetime

class WeatherDashboard:
    def __init__(self):
        self.api_key = os.getenv('OPENWEATHER_API_KEY')
        self.bucket_name = os.getenv('AWS_BUCKET_NAME')
        self.region = os.environ['AWS_REGION']
        self.s3_client = boto3.client('s3', region_name=self.region)

    def create_bucket_if_not_exists(self):
        """First check if bucket exists"""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"Bucket {self.bucket_name} exists")
            return
        except:
            print(f"bucket {self.bucket_name} does not exist, will be created")
        
        try:
            if self.region == "us-east-1":
                # us-east-1 does not require the LocationConstraint parameter
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            else:
                location = {'LocationConstraint': self.region}
                self.s3_client.create_bucket(Bucket=self.bucket_name,
                                    CreateBucketConfiguration=location)
            print(f"Successfully created bucket '{self.bucket_name}' in region '{self.region}'")
        except Exception as e:
            print(f"Error creating bucket: {e}")

    def fetch_weather(self, city):
        """Fetch weather data from OpenWeather API"""
        base_url = "http://api.openweathermap.org/data/2.5/weather"
        params = {
            "q": city,
            "appid": self.api_key,
            "units": "imperial"
        }

        query_string = urllib.parse.urlencode(params)
        full_url = f"{base_url}?{query_string}"
    
        try:
            with urllib.request.urlopen(full_url) as response:
                data = response.read().decode('utf-8')
                json_data = json.loads(data)
                return json_data
        except Exception as e:
            print(f"Error fetching weather data: {e}")
            return None

    def save_to_s3(self, weather_data, city):
        """Save weather data to S3 bucket"""
        if not weather_data:
            return False
            
        timestamp = datetime.now().strftime('%d%m%Y-%H%M%S')
        file_name = f"weather-data/{city}-{timestamp}.json"
        
        try:
            weather_data['timestamp'] = timestamp
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_name,
                Body=json.dumps(weather_data),
                ContentType='application/json'
            )
            print(f"Successfully saved data for {city} to S3")
            return True
        except Exception as e:
            print(f"Error saving to S3: {e}")
            return False




def process(event, context):
    city = "Manchester"
    sns_topic_arn = os.getenv('SNS_TOPIC_ARN')
    sns_client = boto3.client("sns")

    dashboard = WeatherDashboard()
    dashboard.create_bucket_if_not_exists()

    data = dashboard.fetch_weather(city)
    
    if "error" in data:
        message = f"Error fetching weather information for {city} at this time."
    else:
        description = data.get("weather", [{}])[0].get("description", "N/A")
        temp = data.get("main", {}).get("temp", "N/A")
        humidity = data.get("main", {}).get("humidity", "N/A")
        wind_speed = data.get("wind", {}).get("speed", "N/A")
        today = datetime.now().strftime('%d-%m-%Y, %H:%M')

        message = (
            f"Weather in {city} today ({today})\n"
            f"-> {description}\n"
            f"-> Temperature: {temp} °F\n"
            f"-> Humidity: {humidity}\n"
            f"-> Wind Speed: {wind_speed}\n"
        )
    
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

    success = dashboard.save_to_s3(data, city)
    if success:
        print("Data also saved to S3!")
    else:
        print("Could not save to S3, please try later.")
    
    return {"statusCode": 200, "body": "Data processed and sent to SNS"}
