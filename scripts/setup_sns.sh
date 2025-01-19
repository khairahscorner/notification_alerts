#!/bin/bash

# retrieve necessary variables from .env
# update path to use absolute path for the .env file or it exports all across the system
export $(grep -v '^#' .env | xargs)

# Other variables
SNS_TOPIC="Weather-Alerts"

# Check if topic exists
echo "Checking if topic exists..."
aws sns get-topic-attributes --topic-arn $SNS_TOPIC_ARN > /dev/null 2>&1

# > /dev/null 2>&1: suppresses both command output and error messages by directing both /dev/null
# "$?"" checks status code of previous command for errors (0: successful, 1: fail)
if [ $? -ne 0 ]; then
    # delete current line of the topic in the env file (macOS needs the extra '') 
    sed -i '' '/^SNS_TOPIC_ARN=/d' .env

    echo "Topic does not exist. Creating topic: $SNS_TOPIC..."
    CURRENT_TOPIC_ARN=$(aws sns create-topic --name $SNS_TOPIC --attributes '{"DisplayName":"WeatherAlerts"}' --query 'TopicArn' --output text)
    
    if [ $? -eq 0 ] && [ -n "$CURRENT_TOPIC_ARN" ]; then
        echo "Successfully created topic. ARN: $CURRENT_TOPIC_ARN"

        # add new value to .env
        echo "\\nSNS_TOPIC_ARN=$CURRENT_TOPIC_ARN" >> .env
    else
        echo "Failed to create the topic." >&2
        exit 1
    fi 
else
  echo "Topic already exists."
  CURRENT_TOPIC_ARN=$SNS_TOPIC_ARN
fi

echo "Now subscribing user email $EMAIL"
aws sns subscribe --topic-arn $CURRENT_TOPIC_ARN --protocol email --notification-endpoint $EMAIL  2>/dev/null

if [ $? -eq 0 ]; then
  echo "Successfully subscribed user email $EMAIL: pending confirmation"

else
  echo "Failed to subscribe user email $EMAIL" >&2
  exit 1
fi 
