#!/bin/bash

# retrieve necessary variables from .env
# update path to use absolute path for the .env file or it exports all across the system
export $(grep -v '^#' .env | xargs)

# Other variables
Function1Name="tennis-game-alerts"
Function2Name="alertsforObjectsRetrievedFromS3"

Function1RoleName="PublishGameDayAlertsLambdaRole"
Function2RoleName="AlertsForRetrievedObjectsLambdaRole"


echo "checking if lambda function $Function1Name already exists..."
aws lambda get-function --function-name $Function1Name --region $AWS_REGION > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "lambda function $Function1Name does not exist, creating it..."
    aws lambda create-function --function-name $Function1Name --runtime python3.9 \
        --zip-file fileb://src/alerts_lambda.zip --handler alerts_lambda.process \
        --timeout 10 --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/$Function1RoleName \
        --publish > /dev/null

    if [ $? -ne 0 ]; then
        echo "error creating lambda function $Function1Name"
        exit 1
    fi

    # Step 2: Poll for the function to become active
    while true; do
        STATUS=$(aws lambda get-function --function-name $Function1Name --query 'Configuration.State' --output text 2>/dev/null)

        if [ "$STATUS" == "Active" ]; then
            echo "Lambda function $Function1Name is active and ready."
            break
        else
            echo "Waiting for function $Function1Name to become active (current state: $STATUS)..."
            sleep 5
        fi
    done

    echo "lambda function $Function1Name created successfully, now adding code..."
    aws lambda update-function-configuration --function-name $Function1Name \
        --environment "Variables={OPENWEATHER_API_KEY=$OPENWEATHER_API_KEY,AWS_BUCKET_NAME=$AWS_BUCKET_NAME, SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" > /dev/null

    if [ $? -ne 0 ]; then
        echo "error updating lambda function $Function1Name"
        exit 1
    fi
else
    echo "lambda function $Function1Name already exists"
fi


echo "checking if lambda function $Function2Name already exists..."
aws lambda get-function --function-name $Function2Name --region $AWS_REGION > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "lambda function $Function2Name does not exist, creating it..."
    aws lambda create-function --function-name $Function2Name --runtime python3.9 \
        --zip-file fileb://src/retrieve_lambda.zip --handler retrieve_lambda.lambda_handler \
        --timeout 10 --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/$Function2RoleName \
        --publish > /dev/null

    if [ $? -ne 0 ]; then
        echo "error creating lambda function $Function2Name"
        exit 1
    fi

    while true; do
        STATUS=$(aws lambda get-function --function-name $Function2Name --query 'Configuration.State' --output text 2>/dev/null)

        if [ "$STATUS" == "Active" ]; then
            echo "Lambda function $Function2Name is active and ready."
            break
        else
            echo "Waiting for function $Function2Name to become active (current state: $STATUS)..."
            sleep 5
        fi
    done

    echo "lambda function $Function2Name created successfully, now adding code..."
    aws lambda update-function-configuration --function-name $Function2Name \
        --environment "Variables={BUCKET_NAME=$BUCKET_NAME, SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" > /dev/null

    if [ $? -ne 0 ]; then
        echo "error updating lambda function $Function2Name"
        exit 1
    fi
else
    echo "lambda function $Function2Name already exists"
fi

echo "Done!