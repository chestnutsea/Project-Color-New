# DeepSeek Integration Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                           │
│                    (AnalysisResultView)                          │
│  ┌──────────┬──────────────┬────────────────────────────────┐  │
│  │   色彩   │     分布      │         AI评价 (NEW)           │  │
│  └──────────┴──────────────┴────────────────────────────────┘  │
│                                    │                             │
│                            Observes │                             │
│                                    ▼                             │
│                        ┌────────────────────┐                   │
│                        │  AnalysisResult    │                   │
│                        │  @Published vars   │                   │
│                        │  - clusters        │                   │
│                        │  - photoInfos      │                   │
│                        │  - aiEvaluation ✨ │                   │
│                        └────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ Updates
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                    Analysis Pipeline                             │
│               (SimpleAnalysisPipeline)                           │
│                                                                   │
│  1. Extract Colors  → 2. Cluster → 3. Save → 4. AI Evaluate ✨  │
│                                                                   │
│  ┌────────────┐   ┌──────────┐   ┌──────────┐   ┌───────────┐ │
│  │ Color      │   │ K-Means  │   │ Core     │   │ AI        │ │
│  │ Extraction │ → │ Cluster  │ → │ Data     │ → │ Evaluator │ │
│  │            │   │          │   │          │   │ (NEW) ✨  │ │
│  └────────────┘   └──────────┘   └──────────┘   └───────────┘ │
│                                                        │         │
└────────────────────────────────────────────────────────┼─────────┘
                                                         │
                                                         │ Calls
                                                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  AI Service Layer (NEW) ✨                       │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         ColorAnalysisEvaluator                           │  │
│  │  - evaluateColorAnalysis(result)                         │  │
│  │    ├─→ evaluateOverallComposition()                      │  │
│  │    └─→ evaluateCluster() × N                             │  │
│  │  - Generate prompts from color data                      │  │
│  │  - Parse AI responses                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              │ Uses                              │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         DeepSeekService                                  │  │
│  │  - sendChatRequest(messages)                             │  │
│  │  - chat(systemPrompt, userMessage)                       │  │
│  │  - Handle errors and retries                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │ HTTP POST
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DeepSeek API                                  │
│         https://api.deepseek.com/v1/chat/completions            │
│                                                                   │
│  Request:                           Response:                    │
│  {                                  {                            │
│    "model": "deepseek-chat",          "choices": [{             │
│    "messages": [...],                   "message": {            │
│    "temperature": 0.7,                    "content": "..."      │
│    "max_tokens": 2000                   }                       │
│  }                                    }]                         │
│                                     }                            │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Color Analysis Flow (Existing)

```
Photos → Extract Colors → Cluster → Display Results
```

### 2. AI Evaluation Flow (New) ✨

```
Analysis Complete
    ↓
ColorAnalysisEvaluator.evaluateColorAnalysis()
    ↓
├─→ Overall Evaluation
│   ├─→ Build prompt with all cluster data
│   ├─→ DeepSeekService.chat()
│   └─→ Parse response → OverallEvaluation
│
└─→ Cluster Evaluations (loop)
    ├─→ Build prompt for each cluster
    ├─→ DeepSeekService.chat()
    └─→ Parse response → ClusterEvaluation[]
    ↓
ColorEvaluation object
    ↓
Update AnalysisResult.aiEvaluation
    ↓
UI Auto-refreshes (SwiftUI @Published)
```

## Component Responsibilities

### 🎨 UI Layer

**AnalysisResultView.swift**
- Display analysis results in tabs
- **NEW**: AI评价 tab with loading/error/success states
- Handle user interactions (retry button)
- Observe `AnalysisResult.aiEvaluation` changes

### 🔄 Business Logic Layer

**SimpleAnalysisPipeline.swift**
- Orchestrate color analysis
- **NEW**: Trigger AI evaluation after clustering
- Non-blocking async evaluation

**ColorAnalysisEvaluator.swift** ✨
- Generate evaluation prompts
- Call DeepSeek API
- Parse and structure responses
- Convert color data to HSL/LAB for prompts

### 🌐 Service Layer

**DeepSeekService.swift** ✨
- HTTP client for DeepSeek API
- Request/response models
- Error handling
- Token usage tracking

### 📦 Data Models

**AnalysisModels.swift**
- `AnalysisResult` (updated with aiEvaluation)
- **NEW**: `ColorEvaluation`
- **NEW**: `OverallEvaluation`
- **NEW**: `ClusterEvaluation`

### 🔐 Configuration

**APIConfig.swift** ✨
- Read API key from build settings
- Validate key format
- Provide endpoint URL

**Secrets.xcconfig** ✨
- Store API key (git-ignored)
- Injected into Info.plist via build settings

## Security Architecture

```
┌─────────────────────────────────────────┐
│     Secrets.xcconfig (git-ignored)      │
│     DEEPSEEK_API_KEY = sk-...           │
└────────────────┬────────────────────────┘
                 │
                 │ Build Process
                 ▼
┌─────────────────────────────────────────┐
│         Build Settings                   │
│    $(DEEPSEEK_API_KEY)                  │
└────────────────┬────────────────────────┘
                 │
                 │ Substitution
                 ▼
┌─────────────────────────────────────────┐
│          Info.plist                      │
│    DEEPSEEK_API_KEY: $(DEEPSEEK_...)    │
└────────────────┬────────────────────────┘
                 │
                 │ Runtime
                 ▼
┌─────────────────────────────────────────┐
│         APIConfig.swift                  │
│    Bundle.main.object(forInfo...)       │
└────────────────┬────────────────────────┘
                 │
                 │ Access
                 ▼
┌─────────────────────────────────────────┐
│      DeepSeekService.swift               │
│    Authorization: Bearer sk-...         │
└─────────────────────────────────────────┘
```

## Error Handling Flow

```
API Request
    │
    ├─→ Network Error
    │   └─→ DeepSeekError.networkError
    │       └─→ Display error + retry button
    │
    ├─→ Invalid API Key
    │   └─→ DeepSeekError.invalidAPIKey
    │       └─→ Display configuration error
    │
    ├─→ HTTP Error (4xx/5xx)
    │   └─→ DeepSeekError.apiError
    │       └─→ Parse error message + display
    │
    ├─→ Decode Error
    │   └─→ DeepSeekError.decodingError
    │       └─→ Log error + display generic message
    │
    └─→ Success
        └─→ Update UI with evaluation
```

## Threading Model

```
Main Thread (UI)
    │
    ├─→ User Action: Start Analysis
    │
    └─→ Task.detached(priority: .background)
        │
        ├─→ Extract Colors (concurrent, max 8)
        ├─→ Cluster Colors
        ├─→ Save to Core Data
        │
        └─→ Task.detached(priority: .background)
            │
            └─→ AI Evaluation
                ├─→ Overall evaluation (async)
                └─→ Cluster evaluations (sequential)
                    │
                    └─→ await MainActor.run
                        └─→ Update result.aiEvaluation
                            └─→ UI auto-refreshes
```

## API Request Structure

### Overall Evaluation Request

```json
{
  "model": "deepseek-chat",
  "messages": [
    {
      "role": "system",
      "content": "你是一位专业的色彩分析师..."
    },
    {
      "role": "user",
      "content": "请评价以下照片集的整体色彩组成。\n\n色系 1: 红色 (#D93333)\n  - 照片数量: 5 张\n  - 色调: 0.0°\n  - 饱和度: 75.5%\n  - 明度: 52.9%\n\n..."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

### Cluster Evaluation Request

```json
{
  "model": "deepseek-chat",
  "messages": [
    {
      "role": "system",
      "content": "你是一位专业的色彩分析师。请用简洁、专业的语言评价单个颜色。"
    },
    {
      "role": "user",
      "content": "请评价这个颜色：\n- 颜色名称: 红色\n- Hex: #D93333\n- 色调: 0.0°\n- 饱和度: 75.5%\n- 明度: 52.9%\n- Lab: L=52.1, a=62.3, b=45.2\n- 照片数量: 5 张"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

## Performance Considerations

### Async Operations
- Color extraction: Concurrent (max 8 parallel)
- Clustering: Sequential
- AI evaluation: Sequential (1 overall + N clusters)

### Caching
- Photo colors cached after first extraction
- AI evaluations NOT cached (can be added in future)

### API Costs
- Tokens per analysis: ~500-2000 (depends on cluster count)
- Total API calls: 1 + N (N = number of clusters)
- Example: 5 clusters = 6 API calls

### Optimization Opportunities
1. Batch cluster evaluations in single prompt
2. Cache AI evaluations by color signature
3. Implement rate limiting
4. Add request debouncing

---

**Architecture Version**: 1.0  
**Last Updated**: November 16, 2025

