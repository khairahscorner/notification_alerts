import os
import requests
import boto3
from datetime import datetime
from dotenv import load_dotenv


# Load environment variables
load_dotenv()

class WeatherDashboard:
    def __init__(self):
        self.api_key = os.getenv('OPENWEATHER_API_KEY')
        self.bucket_name = os.getenv('AWS_BUCKET_NAME')
        self.region = os.getenv('AWS_REGION')
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

        try:
            response = requests.get(base_url, params=params)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching weather data: {e}")
            return None


def process():
    city = "Manchester"
    sns_topic_arn = os.getenv('SNS_TOPIC_ARN')

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
    
    sns_client = boto3.client("sns", region_name=dashboard.region)

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


if __name__ == "__main__":
    process()