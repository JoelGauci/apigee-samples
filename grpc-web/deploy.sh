#!/bin/bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ -z "$PROJECT" ]; then
  echo "No PROJECT variable set"
  exit
fi

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

if [ -z "$BACKEND_SERVICE" ]; then
  echo "No BACKEND_SERVICE variable set"
  exit
fi

if ! [ -x "$(command -v jq)" ]; then
  echo "jq command is not on your PATH"
  exit
fi

if ! [ -x "$(command -v protoc)" ]; then
  echo "protoc command is not on your PATH"
  exit
fi

if ! [ -x "$(command -v xxd)" ]; then
  echo "xxd command is not on your PATH"
  exit
fi

replace_element_text() {
  local element_name=$1
  local backend_url=$2
  local file_name=$3
  local match_pattern="<${element_name}>.\\+</${element_name}>"
  local replace_pattern="<${element_name}>${backend_url}</${element_name}>"
  local sed_script="s#${match_pattern}#${replace_pattern}#"
  #  in-place editing
  local SEDOPTION="-i"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SEDOPTION='-i \x27\x27'
  fi
  sed "$SEDOPTION" -e "${sed_script}" "${file_name}"
}

grpcWebEncodeHelloRequest() {
  data="${1}"
  protocEncode="protoc --encode=helloworld.HelloRequest  ./app/pkg/grpc/greeter.proto"
  dataLength=$(echo "${data}" | $protocEncode | wc -c)
  cat <(printf "%.2x%.8x" 0 "${dataLength}" | xxd -r -p) <(echo "${data}" | $protocEncode) | base64 | tr -d '\n\r'
}

PAYLOAD_1="$(grpcWebEncodeHelloRequest 'name: "home"')"
PAYLOAD_2="$(grpcWebEncodeHelloRequest 'name: "<listing onpointerrawupdate=prompt(1) style=display:block>XSS</listing>"')"

echo "Setting the Backend Service in the proxy..."
TARGET_1="./bundle/apiproxy/targets/default.xml"
replace_element_text "URL" "${BACKEND_SERVICE}" "${TARGET_1}"

echo "Building the Java callout"
cd callout || exit
./build-jar.sh
cd ..

echo "Installing npm dependencies..."
npm install

echo "Running apigeelint..."
npm run lint

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN="$(gcloud auth print-access-token)"

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee grpc-web proxy..."
PROXY_NAME=grpc-web
REV=$(apigeecli apis create bundle -f bundle/apiproxy -n $PROXY_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name $PROXY_NAME --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

export PROXY_URL="$APIGEE_HOST/v1/samples/grpc-web"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "-----------------------------"
echo " "
echo "Execute the following cURL commands:"
echo " "
echo "curl -i https://$PROXY_URL/helloworld.Greeter/SayHello -H 'content-type: application/grpc-web-text' --data-raw '$PAYLOAD_1'"
echo " "
echo "curl -i https://$PROXY_URL/helloworld.Greeter/SayHello -H 'content-type: application/grpc-web-text' --data-raw '$PAYLOAD_2'"
echo " "
