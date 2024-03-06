#!/usr/bin/env python3
import boto3
import json
import os
from confluent_kafka import Producer

def create_producer():
    secret_arn = os.environ['KAFKA_SECRET_ARN']
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_arn)
    kafka_secrets = json.loads(response['SecretString'])
    return Producer({
        'bootstrap.servers': 'pkc-619z3.us-east1.gcp.confluent.cloud:9092',
        'sasl.mechanisms': 'PLAIN',
        'security.protocol': 'SASL_SSL',
        'sasl.username': kafka_secrets['API_KEY'],
        'sasl.password': kafka_secrets['API_SECRET']
    })

producer = create_producer()

def delivery_report(err, msg):
    if err is not None:
        print(f'Message delivery failed: {err}')
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}]')

def read_s3_file(bucket, key):
    s3_client = boto3.client('s3')
    obj = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = obj['Body'].read().decode('utf-8')
    return file_content

def lambda_handler(event, context):
    # Extract the S3 URI from the event
    s3_uri = event['detail']['eventDetails']['path']
    # Split the S3 URI to get bucket and key
    s3_parts = s3_uri.replace('s3://', '').split('/', 1)
    bucket = s3_parts[0]
    key = s3_parts[1]

    # Read and print file content from S3
    file_content = read_s3_file(bucket, key)

    producer.produce('purchases', file_content, callback=delivery_report)
    producer.poll(0)
    producer.flush()

    return {
        'statusCode': 200,
        'body': json.dumps('Message sent to Kafka')
    }
