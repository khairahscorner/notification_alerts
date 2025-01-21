#!/bin/bash

# retrieve necessary variables from .env
# update path to use absolute path for the .env file or it exports all across the system
export $(grep -v '^#' .env | xargs)

# Other variables
PublishToSNSTopicPolicyName="PublishToSNSTopic"
S3BucketCreateAccessPolicyName="CreateBucketAccess"
S3BucketListAndGetObjectPolicyName="ListObjectsInS3BucketsAndGetObjectFromBucket"

Function1RoleName="PublishAlertsLambdaRole"
Function2RoleName="AlertsForRetrievedObjectsLambdaRole"

SNS_DEFINITION=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "$SNS_TOPIC_ARN"
        }
    ]
}
EOF
)

# Check if topic exists
echo "Checking if policies exists..."
aws iam create-policy --policy-name $PublishToSNSTopicPolicyName --policy-document "$SNS_DEFINITION"
aws iam create-policy --policy-name $S3BucketCreateAccessPolicyName --policy-document file://policies/create-bucket.json 
aws iam create-policy --policy-name $S3BucketListAndGetObjectPolicyName --policy-document file://policies/list-get-bucket.json 

echo "checking if roles exists..."
aws iam get-role --role-name $Function1RoleName > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "role does not exist. Creating..."
    aws iam create-role --role-name $Function1RoleName --assume-role-policy-document file://policies/lambda-trust-policy.json
    
    if [ $? -eq 0 ]; then
        echo "Successfully created role $Function1RoleName"
        aws iam attach-role-policy --role-name $Function1RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$PublishToSNSTopicPolicyName
        aws iam attach-role-policy --role-name $Function1RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$S3BucketCreateAccessPolicyName
    else
        echo "Failed to create role."
        exit 1
    fi 
else
    echo "Role $Function1RoleName already exists. checking if correct policies are attached"
  
    # List attached policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $Function1RoleName --query "AttachedPolicies[].PolicyName" --output text)
    
    # if the needed policies are not attached, add them
    if ! echo "$ATTACHED_POLICIES" | grep -q "$PublishToSNSTopicPolicyName"; then
        aws iam attach-role-policy --role-name $Function1RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$PublishToSNSTopicPolicyName
    fi

    if ! echo "$ATTACHED_POLICIES" | grep -q "$S3BucketCreateAccessPolicyName"; then
        aws iam attach-role-policy --role-name $Function1RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$S3BucketCreateAccessPolicyName
    fi

    echo "All policies attached correctly"
fi



aws iam get-role --role-name $Function2RoleName > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "role does not exist. Creating..."
    aws iam create-role --role-name $Function2RoleName --assume-role-policy-document file://policies/lambda-trust-policy.json
    
    if [ $? -eq 0 ]; then
        echo "Successfully created role $Function2RoleName"
        aws iam attach-role-policy --role-name $Function2RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$PublishToSNSTopicPolicyName
        aws iam attach-role-policy --role-name $Function2RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$S3BucketListAndGetObjectPolicyName
    else
        echo "Failed to create role."
        exit 1
    fi 
else
    echo "Role $Function2RoleName already exists. checking if correct policies are attached"
  
    # List attached policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $Function2RoleName --query "AttachedPolicies[].PolicyName" --output text)
    
    # if the needed policies are not attached, add them
    if ! echo "$ATTACHED_POLICIES" | grep -q "$PublishToSNSTopicPolicyName"; then
        aws iam attach-role-policy --role-name $Function2RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$PublishToSNSTopicPolicyName
    fi

    if ! echo "$ATTACHED_POLICIES" | grep -q "$S3BucketListAndGetObjectPolicyName"; then
        aws iam attach-role-policy --role-name $Function2RoleName --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$S3BucketListAndGetObjectPolicyName
    fi

    echo "All policies attached correctly"
fi

echo "Done!"