# API Configuration Setup

This directory contains the API configuration files for the Project_Color app.

## Files

- **`APIConfig.swift`**: Swift class that reads API keys from build settings
- **`Secrets.xcconfig`**: Configuration file containing API keys (NOT committed to git)

## Xcode Project Configuration

To enable the API key configuration, you need to configure the Xcode project to use the `Secrets.xcconfig` file:

### Step 1: Add xcconfig to Project

1. Open `Project_Color.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Select the "Info" tab
4. Under "Configurations", expand "Debug" and "Release"
5. For both configurations:
   - Click on "Project_Color" (the project, not the target)
   - Select `Secrets` from the dropdown (if it appears)

### Step 2: Manual Configuration (Alternative)

If the xcconfig file doesn't appear in the dropdown:

1. Open `Project_Color.xcodeproj` in Xcode
2. Select the project → Build Settings
3. Search for "User-Defined"
4. Click "+" to add a new setting
5. Name it `DEEPSEEK_API_KEY`
6. Set the value to: `sk-02551e4b861b4d7abb754abef5d73ae5`

### Step 3: Verify Configuration

Build and run the project. Check the console for:
- ✅ "DEEPSEEK_API_KEY loaded successfully" means the key is configured
- ⚠️ "DEEPSEEK_API_KEY not found in build settings" means additional configuration is needed

## Security Notes

- **`Secrets.xcconfig`** is automatically ignored by git (see `.gitignore`)
- Never commit API keys to version control
- For production apps, consider using:
  - Environment variables
  - Secure key management services (e.g., AWS Secrets Manager)
  - Backend proxy to avoid exposing keys in the client

## API Usage

The API key is accessed through the `APIConfig` singleton:

```swift
let apiKey = APIConfig.shared.deepSeekAPIKey
let isValid = APIConfig.shared.isAPIKeyValid
```

## DeepSeek API

- **Endpoint**: `https://api.deepseek.com/v1/chat/completions`
- **Model**: `deepseek-chat`
- **Documentation**: https://platform.deepseek.com/docs

## Troubleshooting

### "API Key 无效或未配置" Error

1. Check if `DEEPSEEK_API_KEY` is set in Build Settings
2. Ensure the key starts with `sk-` and is at least 20 characters
3. Clean build folder (Cmd+Shift+K) and rebuild
4. Check Info.plist contains the key reference

### API Request Fails

1. Verify internet connection
2. Check the API key is valid on DeepSeek platform
3. Review console logs for detailed error messages
4. Check API rate limits and quotas

