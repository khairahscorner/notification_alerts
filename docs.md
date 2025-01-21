SNS-Lamba-EventBridge architecture

-> create topic, subscribe

-> create policies for respective lambda functions i.e
   - to be able to publish to sns, create a new bucket and put object in buckets
   - to list objects in a bucket and get a specific object in the bucket

-> create role and policies

-> create lambda function, attach role

-> Upload code in [this script](src/alerts_lambda.py) to the function
**Note**: Ensure the 'handler' in your function's runtime settings matches this: 
- `[the name of your lambda function].[the method to run]`
e.g I named my function `alerts.py` and the method to run was `process()`, hence my handler should be `alerts.process`.


-> create eventbridge rule that uses a schedule option, add target (can also create a schedule using the recent Amazon EventBridge Scheduler: serverless scheduler)

-> create another rule for the s3 event pattern, add the target, add necessary resource-based permissions to the target function (in this case, to allow the rule to invoke the lambda function)

- Since the trigger is a simple S3 event; a better choice in this case would be using S3 event notifications
- this works better than EventBridge for near-instant triggers (EventBridge has a slight delay)

However, if you still want to use EventBridge or have more complex event patterns that EventBridge is better suited for:
- Create the trigger rule as above BUT ensure to update the bucket configuration to send notifications to eventBridge for all events in the bucket (it WILL NOT work without it)


Can also run locally with [this script](src/alerts_local.py) but doesn't use AWS Lambda

Would also need to use a .env file with these variables (your local AWS credentials file should also be configured already):
- OPENWEATHER_API_KEY
- AWS_BUCKET_NAME
- AWS_REGION
- BUCKET_NAME
- EMAIL
- AWS_ACCOUNT_ID
- SNS_TOPIC_ARN
