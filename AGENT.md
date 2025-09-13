# Tesseract Storage System - Agent Instructions

## Project Overview

Build a multi-tier time-series data archival system in Python that efficiently handles high-frequency data ingestion, buffering, and long-term storage using AWS services. This system is similar to Apache Iceberg but simpler and optimized for rapid updates.

## System Architecture

### Overall Layout of the System

- **Ingestion Layer**: AWS Lambda functions for data ingestion
- **Buffer Layer**: DynamoDB for short-term data storage
- **Archive Layer**: A multi-tier (based on record age) set of Parquet files in S3 for long-term storage
- **Aggregation Layer**: Configurable time-based aggregation (for example, hourly summaries with min/max/avg)

### Data Properties and Timing

Each piece of data that flows into the system will have:
`sensorId`: Something that identifies the sensor. This may be a compound value like `sensor network` + `station Id`
`refTime`: A reference time of when the value was recorded
`validTime`: A time when the data is valid and actually took place

#### Additional Info

- Data should be saved and grouped by `validTime` - this is the time users are querying and looking for.
- Data may come in out of order. We will ensure the buffer is large enough to have all values and order them before saving them to long term storage.

## Core Requirements

### 1. Data Ingestion System

Where data flows into the system. Most likely as JSON data. All data will have properties that are:

- [ ] Create AWS Lambda function handler for incoming time-series data
- [ ] Support multiple data structure schemas (configurable)
- [ ] Validate and normalize incoming data
- [ ] Write incoming data to DynamoDB buffer tables
- [ ] Handle high-frequency data (up to secondly intervals)
- [ ] Implement error handling and retry logic

### 2. DynamoDB Buffer Management

- [ ] Design DynamoDB table schema for buffered data
- [ ] Implement partition key strategy (time-based + id)
- [ ] Query pattern includes:
  - Show me the latest value for a given id
  - Give me the the past 3 ours of data for a given id
- [ ] Support configurable TTL for buffer cleanup
- [ ] Handle write throttling and scaling
- [ ] Create indexes for efficient querying by the query patterns

### 3. Parquet Archive System

This is the primary archive method method where raw values seen in DynamoDB are saved to Parquet Files.

- [ ] Implement timer-based Lambda for buffer-to-archive processing
- [ ] Efficiently use DynamoDB's export to S3 function, then pick up that file once it's created.
- [ ] Create configurable archival policies (daily→weekly→yearly, etc.)
- [ ] Generate parquet files partitioned by:
  - Group ID (weather station, sensor, etc.)
  - Time periods (configurable: daily, weekly, monthly, yearly)
  - Will need to be multi-tier. First, data may be sent to an updated monthly file, then when the final day is added to the month, update the yearly file. Or some combination of configurable time ranges
- [ ] Store parquet files in S3 with organized folder structure

### 4. Configuration Management

- [ ] Create JSON/YAML configuration schema for:
  - Data structure definitions
  - Grouping strategies (by ID, location, type, etc.)
  - Time period configurations (buffer→short→long term)
  - Aggregation rules and time windows
- [ ] Make configuration shareable for query clients
- [ ] Support multiple dataset configurations simultaneously
- [ ] Version configuration changes

### 5. Data Aggregation System

This is a second output method where raw values seen in DynamoDB are aggregated to hourly values and saved to parquet files.

- [ ] Implement configurable aggregation pipeline
- [ ] Create hourly rollup process with statistics:
  - Average, minimum, maximum values
  - Count of records
  - Standard deviation (optional)
  - First/last values in period
- [ ] Store aggregated data as separate parquet files
- [ ] Support multiple aggregation levels (hourly, daily, weekly)

### 6. Query Interface

- [ ] Can read shared config for the data store
- [ ] Create query abstraction layer that:
  - Routes queries to appropriate storage layer (buffer vs archive)
  - Handles time range queries across multiple parquet files and storage layers
  - Supports both raw and aggregated data access
  - Provides consistent API regardless of storage tier

## Technical Implementation Details

Code should be written in Python, in the main module, `./tesseract`

### Data Schema Requirements

- Support flexible schema evolution
- Handle nested JSON structures
- Maintain consistent timestamp formatting (ISO 8601, UTC timezone)
- Support multiple numeric data types (int, float, decimal) as well as strings

### AWS Lambda Functions Needed

The AWS Lambda function should be rather small and simple where possible, using
these common libraries and a standard AWS Python Runtime.

1. **Ingestion Handler** - Processes incoming data streams
2. **Archive Processor** - Timer-triggered buffer-to-parquet conversion
3. **Aggregation Processor** - Timer-triggered statistical rollups
4. **Metadata Updater** - Maintains catalog information

### Configuration Schema Example

```json
{
  "datasets": {
    "weather_stations": {
      "group_by": "station_id",
      "time_field": "timestamp",
      "buffer_ttl_hours": 168,
      "archive_schedule": {
        "buffer_to_daily": "P1D",
        "daily_to_monthly": "P1M",
        "monthly_to_yearly": "P1Y"
      },
      "aggregations": {
        "hourly": ["avg", "min", "max", "count"],
        "daily": ["avg", "min", "max", "count"]
      }
    }
  }
}
```

### Performance Requirements

- Handle up to 1000 records/second per dataset
- Sub-second query response for recent data (buffer)
- Archive processing should complete within configured time windows
- Support horizontal scaling for multiple datasets

### Monitoring and Observability

- [ ] CloudWatch metrics for ingestion rates
- [ ] Processing lag monitoring
- [ ] Data quality alerts
- [ ] Storage cost tracking
- [ ] Error rate monitoring per dataset

## File Structure to Implement

```text
tesseract/
├── __init__.py
├── ingestion/
│   ├── __init__.py
│   ├── lambda_handler.py
│   └── validators.py
├── storage/
│   ├── __init__.py
│   ├── dynamodb.py
│   ├── parquet_writer.py
│   └── s3_manager.py
├── processing/
│   ├── __init__.py
│   ├── archiver.py
│   └── aggregator.py
├── config/
│   ├── __init__.py
│   ├── schema.py
│   └── manager.py
├── query/
│   ├── __init__.py
│   ├── engine.py
│   └── catalog.py
└── utils/
    ├── __init__.py
    ├── time_utils.py
    └── aws_helpers.py
```

## Dependencies to Add

- `boto3` - AWS SDK
- `pandas` - Data manipulation
- `pyarrow` - Parquet file handling
- `pydantic` - Configuration validation
- `structlog` - Structured logging

## Testing Strategy

Tests should use pytest and live in ./tests. Favor larger scale end to end tests over specific unit tests,
though both is good.

- [ ] Unit tests for each component
- [ ] Integration tests with AWS LocalStack
- [ ] Performance tests with synthetic data
- [ ] End-to-end tests simulating real workloads
- [ ] Configuration validation tests

## Success Criteria

1. System can ingest 1000+ records/second without data loss
2. Query latency < 100ms for recent data, < 5s for archived data
3. Storage costs scale linearly with data volume
4. Zero-downtime configuration updates
5. 99.9% data integrity across all storage tiers
