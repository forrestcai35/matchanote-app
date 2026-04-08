# How to Update Models - Copy & Paste Guide

## Single Source of Truth ✨

You only need to edit models in **ONE place**, then copy-paste to the other!

---

## Files to Edit

### iOS App
```
matchanote-app/matchanote-app/Sources/Models/LLM/ModelConfiguration.swift
```

### Backend
```
matchanote-web/lib/models-config.ts
```

---

## How to Add/Edit/Remove Models

### Option 1: Edit iOS First (Recommended)

1. **Open** `ModelConfiguration.swift`
2. **Find** the section between the `═══` markers (lines 50-117)
3. **Edit** the models in `freeModels` or `premiumModels` arrays
4. **Copy** lines 50-117 (the entire editable section)
5. **Open** `models-config.ts` in the backend
6. **Replace** lines 23-89 with your copied content
7. **Convert** Swift syntax to TypeScript:

**Swift to TypeScript Conversion:**
```swift
// iOS (Swift)
Model(
    displayName: "GPT 4o",
    modelId: "gpt-4o",
    isPremium: true,
    provider: .openai,
    supportsVision: true
),
```

**Becomes:**
```typescript
// Backend (TypeScript)
{
  displayName: 'GPT 4o',
  modelId: 'gpt-4o',
  isPremium: true,
  provider: 'openai',
  supportsVision: true,
},
```

**Quick Find & Replace:**
- `Model(` → `{`
- `)` at end of model → `}`
- `: ` → `: ` (same, just change to single quotes)
- `.openai` → `'openai'`
- `.anthropic` → `'anthropic'`
- `.deepseek` → `'deepseek'`
- `.google` → `'google'`
- `.x` → `'x'`
- `.openRouter` → `'openrouter'`
- `.mistral` → `'mistral'`
- `.perplexity` → `'perplexity'`
- `.groq` → `'groq'`

### Option 2: Edit Backend First

Same process, but reverse the direction!

---

## Example: Adding a New Model

### 1. Add to iOS (`ModelConfiguration.swift`)

Find the `premiumModels` array and add:

```swift
Model(
    displayName: "Claude Opus 4",
    modelId: "claude-opus-4",
    isPremium: true,
    provider: .anthropic,
    supportsVision: true
),
```

### 2. Copy to Backend (`models-config.ts`)

Convert to TypeScript format:

```typescript
{
  displayName: 'Claude Opus 4',
  modelId: 'claude-opus-4',
  isPremium: true,
  provider: 'anthropic',
  supportsVision: true,
},
```

---

## Example: Removing a Model

Just **delete** the entire `Model(...)` block from both files!

```swift
// DELETE THIS:
Model(
    displayName: "Old Model",
    modelId: "old-model-v1",
    isPremium: true,
    provider: .openai,
    supportsVision: false
),
```

---

## Example: Changing a Model to Free

Change `isPremium` from `true` to `false` **AND** move it from `premiumModels` to `freeModels`:

### Before:
```swift
// In premiumModels array
Model(
    displayName: "Gemini Flash",
    modelId: "gemini-1.5-flash",
    isPremium: true,  // ← Change this
    provider: .google,
    supportsVision: true
),
```

### After:
```swift
// Move to freeModels array
Model(
    displayName: "Gemini Flash",
    modelId: "gemini-1.5-flash",
    isPremium: false,  // ← Changed!
    provider: .google,
    supportsVision: true
),
```

Do the same in both files!

---

## Current Models (Reference)

### Free Models:
- **Matcha Assistant** (`google/gemini-2.0-flash-exp:free`) - OpenRouter

### Premium Models:
- **GPT 5.1** (`gpt-5.1`) - OpenAI
- **Sonnet 4.5** (`claude-sonnet-4-5-20250929`) - Anthropic
- **Gemini 3 Pro** (`gemini-3.0-pro`) - Google
- **Grok 4** (`grok-4-fast-non-reasoning`) - X.AI
- **Deepseek V3** (`deepseek-chat`) - DeepSeek
- **Mistral Large** (`mistral-large-latest`) - Mistral
- **Perplexity Sonar** (`sonar`) - Perplexity

---

## Model Properties Explained

| Property | Description | Example |
|----------|-------------|---------|
| `displayName` | User-facing name shown in app | `"GPT 4o"` |
| `modelId` | API model identifier | `"gpt-4o"` |
| `isPremium` | Requires premium subscription | `true` or `false` |
| `provider` | API provider | `openai`, `anthropic`, etc. |
| `supportsVision` | Can process images | `true` or `false` |

---

## Testing After Changes

### 1. Build iOS App
```bash
cd matchanote-app
# Build in Xcode - check for compile errors
```

### 2. Deploy Backend
```bash
cd matchanote-web
npm run build  # Check for TypeScript errors
git add lib/models-config.ts app/api/llm/route.ts
git commit -m "Update model configuration"
git push
```

### 3. Test End-to-End
- Open iOS app
- Select the new/modified model
- Send a test message
- Verify it works!

---

## Common Issues

### ❌ Model not showing in iOS app
- Check `freeModels` or `premiumModels` array
- Make sure you saved the file
- Rebuild the app

### ❌ Backend returns "Unsupported model"
- Check `models-config.ts` has the model
- Make sure `modelId` matches exactly
- Redeploy backend

### ❌ "Missing API key" error
- Check `.env` file has the provider's API key
- Example: `OPENAI_API_KEY=sk-...`

---

## Pro Tips 💡

1. **Always update both files** - iOS and backend must match!
2. **Test with a free model first** - before adding premium models
3. **Keep `modelId` unique** - no two models should have the same ID
4. **Use descriptive `displayName`** - users see this in the UI
5. **Set `supportsVision: false`** if you're not sure - safer default

---

## Quick Reference: Provider Values

| Provider | iOS Value | Backend Value |
|----------|-----------|---------------|
| OpenAI | `.openai` | `'openai'` |
| Anthropic | `.anthropic` | `'anthropic'` |
| DeepSeek | `.deepseek` | `'deepseek'` |
| Google | `.google` | `'google'` |
| X.AI (Grok) | `.x` | `'x'` |
| OpenRouter | `.openRouter` | `'openrouter'` |
| Mistral | `.mistral` | `'mistral'` |
| Perplexity | `.perplexity` | `'perplexity'` |
| Groq | `.groq` | `'groq'` |

---

**That's it!** Just edit, copy, paste, and deploy. 🚀
