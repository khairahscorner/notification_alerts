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


-> create eventbridge rule and use a schedule option, attach rule to lambda function invoke



Can also run locally with [this script](src/alerts_local.py) but doesn't use AWS Lambda

Would also need to use a .env file with these variables (your local AWS credentials file should also be configured already):
- OPENWEATHER_API_KEY
- AWS_BUCKET_NAME
- AWS_REGION
- SNS_TOPIC_ARN
