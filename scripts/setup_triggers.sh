#!/bin/bash

# retrieve necessary variables from .env
# update path to use absolute path for the .env file or it exports all across the system
export $(grep -v '^#' .env | xargs)

# Other variables
SCHEDULE_NAME="weather-alerts-schedule"
TRIGGER_NAME="weather-alerts-upload-trigger"
Function1Name="weather-alerts"
Function2Name="alertsforObjectsRetrievedFromS3"
EventBridgePermissionStatementId="statement-lambda-eventbridge"


echo "checking for matching events $SCHEDULE_NAME"
aws events describe-rule --name $SCHEDULE_NAME --region $AWS_REGION > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "creating schedule for daily weather alerts"
    aws events put-rule --name $SCHEDULE_NAME --schedule-expression "cron(0 8,12,16 * * ? *)" --region $AWS_REGION

    if [ $? -ne 0 ]; then
        echo "Failed to create schedule $SCHEDULE_NAME"
        exit 1
    else
        aws events put-targets --rule $SCHEDULE_NAME \
        --targets "Id"="$SCHEDULE_NAME-$Function1Name","Arn"="arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$Function1Name"
    fi
else
    echo "Schedule $SCHEDULE_NAME already exists"
fi

# Optimal choice for invoking lambda function for simple s3 events triggers: 
echo "adding configuration to bucket $BUCKET_NAME for function $Function2Name"
aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME --region $AWS_REGION \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
            {
                "LambdaFunctionArn": "arn:aws:lambda:'"$AWS_REGION"':'"$AWS_ACCOUNT_ID"':function:'"$Function2Name"'",
                "Events": ["s3:ObjectCreated:*"]
            }
        ]
    }'

if [ $? -ne 0 ]; then
        echo "Failed to add configuration to bucket $BUCKET_NAME"
        exit 1
    fi

else 
    echo "Successfully setup s3 event notifications for bucket $BUCKET_NAME to trigger lambda function $Function2Name"

echo "DONE!"


## Other choice: Using EventBridge with event pattern

# EVENT_PATTERN=$(cat <<EOF
# {
#   "source": ["aws.s3"],
#   "detail-type": ["Object Created"],
#   "detail": {
#     "bucket": {
#       "name": ["$BUCKET_NAME"]
#     }
#   }
# }
# EOF
# )

# echo "checking for matching events $TRIGGER_NAME"
# aws events describe-rule --name $TRIGGER_NAME --region $AWS_REGION > /dev/null 2>&1

# if [ $? -ne 0 ]; then
#     echo "creating schedule for alerts to retrieve last added object to S3 bucket $BUCKET_NAME"
#     aws events put-rule --name $TRIGGER_NAME --event-pattern "$EVENT_PATTERN" --region $AWS_REGION

#     if [ $? -ne 0 ]; then
#         echo "Failed to create rule $TRIGGER_NAME"
#         exit 1
#     else
#         aws events put-targets --rule $TRIGGER_NAME \
#         --targets "Id"="$TRIGGER_NAME-$Function2Name","Arn"="arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$Function2Name"
#     fi

#     echo "now checking whether function $Function2Name already has resource permissions"
#     aws lambda get-policy --function-name $Function2Name --region $AWS_REGION | grep -q $EventBridgePermissionStatementId > /dev/null 2>&1

#     if [ $? -ne 0 ]; then
#         echo "no matching permissions found, now attaching resource permissions for event rule $TRIGGER_NAME to function $Function2Name"
#         aws lambda add-permission \
#         --function-name $Function2Name \
#         --statement-id $EventBridgePermissionStatementId \
#         --action "lambda:InvokeFunction" \
#         --principal "events.amazonaws.com" \
#         --source-arn "arn:aws:events:$AWS_REGION:$AWS_ACCOUNT_ID:rule/$TRIGGER_NAME" \
#         --region $AWS_REGION

#         if [ $? -ne 0 ]; then
#             echo "Failed to add resource permissions"
#             exit 1
#         fi
#     else
#         echo "resource permissions already exist"
#     fi

#     echo "now ensuring bucket $BUCKET_NAME has turned on notifications for eventBridge"
#     aws s3api put-bucket-notification-configuration --bucket $BUCKET_NAME --region $AWS_REGION \
#     --notification-configuration='{ "EventBridgeConfiguration": {} }'

#     if [ $? -ne 0 ]; then
#         echo "Failed to turn on bucket event notifications"
#         exit 1
#     else
#         echo "Successfully setup s3 event notifications for bucket $BUCKET_NAME to trigger lambda function $Function2Name"
#     fi
# else
#     echo "Schedule $TRIGGER_NAME already exists"
# fi
# echo "DONE!"