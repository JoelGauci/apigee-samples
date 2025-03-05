#!/bin/bash

#  Copyright 2024 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -e

REGION=${REGION:-us-west1}

gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

gcloud run deploy apigee-grpc-web-backend \
  --allow-unauthenticated \
  --timeout 3600 \
  --region="${REGION}" \
  --source=.

BACKEND_SERVICE=$(gcloud run services describe apigee-grpc-web-backend --platform managed --region "$REGION" --format 'value(status.url)')

echo " Your gRPC-Web App is deployed to Cloud Run"
echo " Export the following environment variable: "
echo " export BACKEND_SERVICE=${BACKEND_SERVICE} "
echo " "
