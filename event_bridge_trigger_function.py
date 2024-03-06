import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    client = boto3.client('events')

    # Define a CDA-like event detail
    cda_event_detail = {
        "tenantId": "guidewire",
        "dataProductId": "6f9f55fcd5f94e18adc253b9a6ec1402",
        "customerEnvironment": "us-east-1",
        "sourceInsuranceSuiteApp": "pc",
        "eventType": "cda.batchModeTableWrittenOut",
        "eventDetails": {
            "tableName": "pc_account",
            "path": "s3://shubhrose-bucket/pc_account_data.csv",
            "numRecords": 2661
        }
    }

    response = client.put_events(
        Entries=[
            {
                'EventBusName': 'shubhroses_event_bus_terraform',
                'DetailType': 'CDA Service Lifecycle Events',
                'Source': 'CDA',
                'Time': datetime.utcnow().isoformat(),
                'Detail': json.dumps(cda_event_detail)
            }
        ]
    )

    return {
        'statusCode': 200,
        'body': json.dumps('CDA-like event sent to EventBridge')
    }
