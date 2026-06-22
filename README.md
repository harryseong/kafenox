# Kafenox

A personal coffee-bag catalog. Photograph a roasted coffee bag with your iPhone; an AWS backend resizes the photo, sends it to a Bedrock Claude model to extract structured coffee data (roaster, origin, roast date, flavor notes, etc.), and saves it to DynamoDB. The iOS app lets you browse/search the catalog, see a world map of origins, and rate each coffee.

## Repo layout

```
kafenox/
├── backend/   AWS CDK app (Python) — S3, DynamoDB, Step Functions, Bedrock, API Gateway
├── ios/       SwiftUI app (iOS 26)
└── web/       React + Vite app — not started yet
```

## Prerequisites

- Python 3.12+
- Docker Desktop, **running** (CDK bundles Lambda dependencies via Docker)
- AWS CLI configured with credentials that can deploy CDK stacks in `ap-southeast-1` (or your chosen region)
- Bedrock model access: in the AWS console, enable access to Anthropic Claude models in **Bedrock → Model access** for `ap-southeast-1`, and confirm the current APAC cross-region inference profile ID (see `backend/kafenox_cdk/config.py` — AWS adds new profile IDs as new Claude versions ship, the default hardcoded there may go stale)
- Xcode 16+ (iOS 26 SDK) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) for the iOS app

## Backend — build, deploy, run

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
```

**Run tests** (CDK assertions + Lambda logic, no AWS account needed):

```bash
pytest tests/ -v
```

**Synthesize** (validates the CDK app without deploying):

```bash
npx aws-cdk synth --all
```

**Bootstrap your AWS account** (one-time per account/region):

```bash
npx aws-cdk bootstrap aws://<ACCOUNT_ID>/ap-southeast-1
```

**Deploy** all three stacks:

```bash
npx aws-cdk deploy --all
```

This deploys `KafenoxStorage-dev`, `KafenoxProcessing-dev`, and `KafenoxApi-dev` (the `-dev` suffix comes from `KAFENOX_ENV`, default `dev` — set that env var to deploy a separate `prod` stack later). Note the `KafenoxApi-dev` stack's output API URL.

**Retrieve the API key** the iOS app needs:

```bash
aws apigateway get-api-keys --name-query kafenox-ios-dev --include-values \
  --query 'items[0].value' --output text
```

**Smoke test** the upload pipeline end-to-end:

```bash
API_URL="<api-url-from-stack-output>"
API_KEY="<key-from-above>"

curl -s -X POST "$API_URL/uploads" -H "x-api-key: $API_KEY" | tee /tmp/upload.json
PHOTO_ID=$(python3 -c "import json;print(json.load(open('/tmp/upload.json'))['photoId'])")
UPLOAD_URL=$(python3 -c "import json;print(json.load(open('/tmp/upload.json'))['uploadUrl'])")

curl -s -X PUT "$UPLOAD_URL" -H "Content-Type: image/jpeg" --data-binary @/path/to/coffee-bag.jpg

# poll until status is COMPLETE or FAILED
curl -s "$API_URL/uploads/$PHOTO_ID/status" -H "x-api-key: $API_KEY"

curl -s "$API_URL/coffees/$PHOTO_ID" -H "x-api-key: $API_KEY"
```

To tear everything down:

```bash
npx aws-cdk destroy --all
```

## iOS — build & run

```bash
cd ios/Kafenox
xcodegen generate
open Kafenox.xcodeproj
```

Before running against a real backend, two things need to point at your deployment:

1. **API base URL** — edit `ios/Kafenox/Kafenox/Networking/APIConfig.swift`, replace the placeholder `baseURL` with your deployed `KafenoxApi-dev` stage URL.
2. **API key** — there's no in-app provisioning UI yet (single-user app, deploy is infrequent). Temporarily add this line in `KafenoxApp.swift`'s initializer, run the app once on your device/simulator, then remove the line:
   ```swift
   KeychainStore.set("YOUR_API_KEY")
   ```
   The key persists in the Keychain across app launches/rebuilds after that.

Then build and run from Xcode (⌘R) targeting a simulator or your device. Camera capture (the Scan tab) requires a physical device — the simulator has no camera.

Whenever you add/remove Swift files or change `project.yml` (e.g. font resources), re-run `xcodegen generate` to regenerate `Kafenox.xcodeproj`.

## Web

Not started yet — `web/` is a placeholder for a future React + Vite frontend.
