#!/bin/bash

QUERY=$(cat <<-EOT
    CREATE DATABASE IF NOT EXISTS alb_db;

    CREATE EXTERNAL TABLE IF NOT EXISTS alb_logs_partitioned (
        type string,
        time string,
        elb string,
        client_ip string,
        client_port int,
        target_ip string,
        target_port int,
        request_processing_time double,
        target_processing_time double,
        response_processing_time double,
        elb_status_code int,
        target_status_code string,
        received_bytes bigint,
        sent_bytes bigint,
        request_verb string,
        request_url string,
        request_proto string,
        user_agent string,
        ssl_cipher string,
        ssl_protocol string,
        target_group_arn string,
        trace_id string,
        domain_name string,
        chosen_cert_arn string,
        matched_rule_priority string,
        request_creation_time string,
        actions_executed string,
        redirect_url string,
        lambda_error_reason string,
        target_port_list string,
        target_status_code_list string,
        classification string,
        classification_reason string
        )
        PARTITIONED BY(day string)
        ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
        WITH SERDEPROPERTIES (
        'serialization.format' = '1',
        'input.regex' =
        '([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) ([^ ]*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-]+) ([A-Za-z0-9.-]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^\"]*)\" ([-.0-9]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^ ]*)\" \"([^\s]+?)\" \"([^\s]+)\" \"([^ ]*)\" \"([^ ]*)\"')
        LOCATION 's3://${2}/alb-logs/AWSLogs/${1}/elasticloadbalancing/ap-south-1/';

    ALTER TABLE alb_logs_partitioned ADD
    PARTITION (day = '2024/01/18')
    LOCATION 's3://${2}/alb-logs/AWSLogs/${1}/elasticloadbalancing/ap-south-1/2024/01/18/';
EOT
)

ESCAPED_QUERY=$(echo "$QUERY" | tr -d '\n')
aws athena start-query-execution --query-string "$ESCAPED_QUERY" --result-configuration OutputLocation=s3://${2} --profile ${3}
