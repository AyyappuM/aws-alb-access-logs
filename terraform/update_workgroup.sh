#!/bin/bash

aws athena update-work-group --work-group primary --configuration "ResultConfigurationUpdates={OutputLocation=s3://ayyappu-test-bucket-athena}" --profile a2
