import { useState } from 'react'
import type { VisionResult, DiscardJudgment, PhotoAnalysisItem } from '../types'

export interface StreamCallbacks {
  onItem?: (item: PhotoAnalysisItem, index: number) => void
  onBadPhoto?: (reason: string) => void
  onDone?: (allItems: PhotoAnalysisItem[], skippedCount: number) => void
  onError?: (error: Error) => void
}

const API_KEY_STORAGE = 'ikebana_api_key'

// ─── Vision model configuration ─────────────────────────────────────────

// Primary: Qwen3-VL-Flash via 百炼 DashScope
const VISION_MODEL = 'qwen3-vl-flash'
const VISION_ENDPOINT = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'

// Fallback: DeepSeek V4-Flash
const FALLBACK_VISION_MODEL = 'deepseek-v4-flash'
const FALLBACK_VISION_ENDPOINT = 'https://api.deepseek.com/chat/completions'

// Shared system prompts (model-agnostic)
const STREAM_SYSTEM_PROMPT = `你是物品识别和断舍离助手。分析照片中所有可见物品。

## 任务
识别照片中所有物品。每识别出一件，立即输出该物品的JSON（一行一个），不要等全部识别完。

## 每件物品输出格式（每行独立JSON）
{"name":"物品名","category":"衣物/书籍/电子产品/厨房用品/日用品/纪念品/杂物/家具/装饰品/美妆","estimatedPrice":数字,"condition":"new/good/fair/poor","discardScore":0-100,"suggestion":"keep/consider/discard","reason":"简短理由"}

## 无法识别时
如果照片模糊/太暗/无物品，输出:
{"badPhoto":true,"badPhotoReason":"原因"}

## 规则
- 每行一个完整JSON对象（用换行分隔，不要JSON数组）
- 评分仅根据照片中能观察的信息判断，不确定情感价值时倾向保留（低分）
- 不要输出markdown或解释文字`

const BATCH_SYSTEM_PROMPT = `你是物品识别和断舍离助手。分析用户拍摄的照片。

## 任务
识别照片中所有可见的物品，不要遗漏任何一件。

## 对每件物品输出
1. name: 物品名称
2. category: 衣物/书籍/电子产品/厨房用品/日用品/纪念品/杂物/家具/装饰品/美妆
3. estimatedPrice: 估算人民币市场二手价（数字，没有则填0）
4. condition: new/good/fair/poor
5. discardScore: 0-100 可丢程度（0=绝对保留，100=赶紧扔）
6. suggestion: keep/consider/discard
7. reason: 一句话理由

## 评分标准（仅根据照片中能观察到的信息判断）
- 0-20: 品相好且有使用痕迹（被珍惜）、有明显情感标记（照片/手写标签/礼物包装）→ 保留
- 21-40: 品相好、实用价值高、无明显丢弃理由 → 倾向保留
- 41-60: 品相一般、功能可替代、无明显情感标记 → 中立
- 61-80: 品相差、过时/损坏、有可替代品 → 可以丢弃
- 81-100: 明显坏掉、过期、无用碎片/包装/废弃物 → 赶紧扔

当不确定情感价值时，倾向保留（给较低的丢弃分）。

## 照片质量检查（重要！）
如果照片模糊、过暗/过曝、或没有可识别物品，请勿猜测或编造物品。
直接返回：
{"badPhoto": true, "badPhotoReason": "具体原因（如：照片太暗/模糊/没有物品）", "items": []}

只有照片清晰可辨识时，才进行物品分析。

## 输出格式（严格JSON，不要markdown代码块）
{"badPhoto": false, "items": [{"name": "...", "category": "...", "estimatedPrice": 数字, "condition": "new/good/fair/poor", "discardScore": 数字, "suggestion": "keep/consider/discard", "reason": "..."}]}`

// ─── Body builders ──────────────────────────────────────────────────────

/**
 * Strip the MIME prefix from a data URL.
 * "data:image/jpeg;base64,xxx" → "xxx"
 */
function stripMimePrefix(dataUrl: string): string {
  const commaIdx = dataUrl.indexOf(',')
  return commaIdx >= 0 ? dataUrl.slice(commaIdx + 1) : dataUrl
}

function buildQwenStreamBody(base64DataUrl: string) {
  return {
    model: VISION_MODEL,
    max_tokens: 2048,
    temperature: 0.0,
    stream: true,
    messages: [
      { role: 'system', content: STREAM_SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'image_url', image_url: { url: base64DataUrl } },
          { type: 'text', text: '逐一识别这张照片中的物品' },
        ],
      },
    ],
  }
}

function buildDeepSeekStreamBody(base64DataUrl: string) {
  return {
    model: FALLBACK_VISION_MODEL,
    max_tokens: 2048,
    temperature: 0.0,
    stream: true,
    messages: [
      { role: 'system', content: STREAM_SYSTEM_PROMPT },
      { role: 'user', content: '逐一识别这张照片中的物品' },
    ],
    image_data: stripMimePrefix(base64DataUrl),
  }
}

function buildQwenBatchBody(base64DataUrl: string) {
  return {
    model: VISION_MODEL,
    max_tokens: 2048,
    temperature: 0.0,
    stream: false,
    messages: [
      { role: 'system', content: BATCH_SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'image_url', image_url: { url: base64DataUrl } },
          { type: 'text', text: '分析这张照片中的物品，识别所有可见物品并给出断舍离建议' },
        ],
      },
    ],
  }
}

/**
 * Parse JSON from AI response content, handling possible markdown
 * code block wrapping. Throws if the content cannot be parsed.
 */
function parseJSONFromContent(content: string): any {
  const cleaned = content
    .replace(/^```(?:json)?\s*\n?/i, '')
    .replace(/\n?\s*```\s*$/, '')
    .trim()

  if (!cleaned) {
    throw new Error('AI 返回格式异常，请重试')
  }

  try {
    return JSON.parse(cleaned)
  } catch {
    throw new Error('AI 返回格式异常，请重试')
  }
}

/**
 * Validate that a VisionResult has the expected shape.
 */
function validateVisionResult(data: any): VisionResult {
  if (!data || typeof data !== 'object') {
    throw new Error('AI 返回格式异常，请重试')
  }

  // Ensure items is an array
  const items = Array.isArray(data.items) ? data.items : []
  const badPhoto = typeof data.badPhoto === 'boolean' ? data.badPhoto : false
  const badPhotoReason = typeof data.badPhotoReason === 'string' ? data.badPhotoReason : undefined

  return { items, badPhoto, badPhotoReason }
}

/**
 * Validate that a DiscardJudgment has the expected shape.
 */
function validateDiscardJudgment(data: any): DiscardJudgment {
  if (!data || typeof data !== 'object') {
    throw new Error('AI 返回格式异常，请重试')
  }

  const discardScore =
    typeof data.discardScore === 'number' && data.discardScore >= 0 && data.discardScore <= 100
      ? data.discardScore
      : 50

  const reason = typeof data.reason === 'string' ? data.reason : '无法判断'

  const validSuggestions = ['keep', 'consider', 'discard'] as const
  const suggestion = validSuggestions.includes(data.suggestion) ? data.suggestion : 'consider'

  return { discardScore, reason, suggestion }
}

async function fetchWithRetry(
  body: object,
  apiKey: string,
  maxRetries = 3,
  endpoint: string = FALLBACK_VISION_ENDPOINT
): Promise<Response> {
  let lastError: Error | null = null

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      // Exponential backoff: 1s, 2s, 4s
      const delay = Math.min(1000 * Math.pow(2, attempt - 1), 10000)
      await new Promise(resolve => setTimeout(resolve, delay))
    }

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify(body),
      })

      // Don't retry client errors (except 429)
      if (response.status === 401 || response.status === 402 || response.status === 422) {
        return response
      }

      // Retry on server errors and network failures
      if (!response.ok && response.status !== 429) {
        lastError = new Error(`HTTP ${response.status}`)
        continue
      }

      return response
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err))
    }
  }

  throw lastError || new Error('请求失败，请检查网络连接')
}

/**
 * Standalone batch API call — reusable by both analyzePhotoBatch (hook method)
 * and the stream fallback path in analyzePhotoStream.
 */
async function fetchBatchResult(base64DataUrl: string, apiKey: string): Promise<VisionResult> {
  const body = buildQwenBatchBody(base64DataUrl)

  const response = await fetchWithRetry(body, apiKey, 3, VISION_ENDPOINT)

  if (!response.ok) {
    if (response.status === 401) throw new Error('API Key 无效，请在设置中更新')
    if (response.status === 402) throw new Error('API 账户余额不足，请充值后重试')
    if (response.status === 422) throw new Error('请求参数错误，请联系开发者')
    if (response.status === 429) throw new Error('请求太频繁，请稍后重试')
    throw new Error(`AI 服务错误 (${response.status})`)
  }

  const json = await response.json()
  const content: string = json.choices?.[0]?.message?.content ?? ''
  const parsed = parseJSONFromContent(content)
  return validateVisionResult(parsed)
}

export function useVision() {
  const [apiKey, setApiKeyState] = useState<string>(
    () => localStorage.getItem(API_KEY_STORAGE) || ''
  )
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const saveApiKey = (key: string) => {
    const trimmed = key.trim()
    localStorage.setItem(API_KEY_STORAGE, trimmed)
    setApiKeyState(trimmed)
  }

  const clearApiKey = () => {
    localStorage.removeItem(API_KEY_STORAGE)
    setApiKeyState('')
  }

  const analyzePhotoBatch = async (base64DataUrl: string): Promise<VisionResult> => {
    if (!apiKey) throw new Error('未配置 API Key，请在设置中添加')

    setLoading(true)
    setError(null)

    try {
      return await fetchBatchResult(base64DataUrl, apiKey)
    } catch (err) {
      if (err instanceof SyntaxError) {
        const msg = 'AI 返回格式异常，请重试（如重复出现请重拍照片）'
        setError(msg)
        throw new Error(msg)
      }
      const msg = err instanceof Error ? err.message : '未知错误'
      setError(msg)
      throw err
    } finally {
      setLoading(false)
    }
  }

  /**
   * Streaming version of analyzePhoto.
   * Items are reported one-by-one via onItem callback as the model generates them,
   * enabling progressive UI updates instead of waiting for the full response.
   */
  const analyzePhotoStream = async (
    base64DataUrl: string,
    callbacks: StreamCallbacks,
    key: string
  ): Promise<void> => {
    if (!key) throw new Error('未配置 API Key，请在设置中添加')

    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${key}`,
    }

    const qwenBody = buildQwenStreamBody(base64DataUrl)
    const deepseekBody = buildDeepSeekStreamBody(base64DataUrl)

    // ── Try primary model (Qwen), fall back to DeepSeek on any error ───

    let response: Response

    try {
      response = await fetch(VISION_ENDPOINT, {
        method: 'POST',
        headers,
        body: JSON.stringify(qwenBody),
      })
    } catch (primaryNetworkErr) {
      console.warn('Qwen API unreachable, falling back to DeepSeek:', primaryNetworkErr)
      response = await fetch(FALLBACK_VISION_ENDPOINT, {
        method: 'POST',
        headers,
        body: JSON.stringify(deepseekBody),
      })
    }

    // If primary returned any error status, try fallback
    if (!response.ok) {
      console.warn(`Qwen returned ${response.status}, falling back to DeepSeek`)
      try {
        response = await fetch(FALLBACK_VISION_ENDPOINT, {
          method: 'POST',
          headers,
          body: JSON.stringify(deepseekBody),
        })
      } catch (fallbackNetworkErr) {
        throw new Error(`AI 服务不可用: ${fallbackNetworkErr instanceof Error ? fallbackNetworkErr.message : '网络错误'}`)
      }
    }

    // ── Error handling (after any fallback) ────────────────────────────

    if (!response.ok) {
      if (response.status === 401) throw new Error('API Key 无效，请在设置中更新')
      if (response.status === 402) throw new Error('API 账户余额不足，请充值后重试')
      if (response.status === 422) throw new Error('请求参数错误，请联系开发者')
      if (response.status === 429) throw new Error('请求太频繁，请稍后重试')
      throw new Error(`AI 服务错误 (${response.status})`)
    }

    const reader = response.body?.getReader()
    if (!reader) throw new Error('不支持流式响应')

    const decoder = new TextDecoder()
    let sseBuffer = ''
    let contentBuffer = ''
    const allItems: PhotoAnalysisItem[] = []
    let index = 0
    let badPhotoSignaled = false
    let skippedLines = 0
    let receivedContent = false

    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        sseBuffer += decoder.decode(value, { stream: true })
        const sseLines = sseBuffer.split('\n')
        sseBuffer = sseLines.pop() || ''

        for (const sseLine of sseLines) {
          const trimmed = sseLine.trim()
          if (!trimmed) continue

          const dataStr = trimmed.startsWith('data: ') ? trimmed.slice(6) : trimmed
          if (dataStr === '[DONE]') continue

          try {
            const parsed = JSON.parse(dataStr)
            const deltaContent: string = parsed.choices?.[0]?.delta?.content || ''
            if (!deltaContent) continue

            receivedContent = true
            contentBuffer += deltaContent
            const contentLines = contentBuffer.split('\n')
            contentBuffer = contentLines.pop() || ''

            for (const contentLine of contentLines) {
              const trimmedContent = contentLine.trim()
              if (!trimmedContent) continue

              try {
                const itemJson = JSON.parse(trimmedContent)
                if (itemJson.badPhoto) {
                  badPhotoSignaled = true
                  callbacks.onBadPhoto?.(itemJson.badPhotoReason || '照片不合格')
                  return
                }
                if (itemJson.name) {
                  allItems.push(itemJson as PhotoAnalysisItem)
                  callbacks.onItem?.(itemJson as PhotoAnalysisItem, index++)
                }
              } catch {
                // skip lines that aren't valid JSON (partial/incomplete chunks)
                skippedLines++
              }
            }
          } catch {
            // skip unparseable SSE chunks
          }
        }
      }

      // Process any remaining content in the buffer (last line may not end with \n)
      if (contentBuffer.trim()) {
        try {
          const itemJson = JSON.parse(contentBuffer.trim())
          if (itemJson.badPhoto && !badPhotoSignaled) {
            callbacks.onBadPhoto?.(itemJson.badPhotoReason || '照片不合格')
            return
          }
          if (itemJson.name) {
            allItems.push(itemJson as PhotoAnalysisItem)
            callbacks.onItem?.(itemJson as PhotoAnalysisItem, index++)
          }
        } catch {
          // incomplete JSON fragment at end of stream, ignore
          skippedLines++
        }
      }
    } finally {
      reader.releaseLock()
    }

    // Fallback: stream produced content but we couldn't parse any items
    if (allItems.length === 0 && receivedContent && !badPhotoSignaled) {
      try {
        const batchResult = await fetchBatchResult(base64DataUrl, key)
        if (batchResult.badPhoto) {
          callbacks.onBadPhoto?.(batchResult.badPhotoReason || '照片不合格')
          return
        }
        batchResult.items.forEach((item, i) => {
          allItems.push(item)
          callbacks.onItem?.(item, i)
        })
      } catch (err) {
        callbacks.onError?.(err instanceof Error ? err : new Error('识别失败'))
        return
      }
    }

    callbacks.onDone?.(allItems, skippedLines)
  }

  const judgeItem = async (item: {
    name: string
    category: string
    estimatedPrice?: number
    condition: string
  }): Promise<DiscardJudgment> => {
    if (!apiKey) throw new Error('未配置 API Key，请在设置中添加')

    setLoading(true)
    setError(null)

    try {
      const body = {
        model: 'deepseek-v4-flash',
        max_tokens: 256,
        temperature: 0.0,
        stream: false,
        messages: [
          {
            role: 'system',
            content: `你是断舍离顾问。根据物品信息，评估"可丢程度"(0-100分)。
评分标准:
- 0-20: 高频使用、情感重要、不可替代 → 绝对留着
- 21-40: 偶尔用、有替代品但成本高 → 倾向留着
- 41-60: 可留可丢、看心情 → 中立
- 61-80: 很少用、占地方、价值低 → 可以丢
- 81-100: 完全没用、坏掉了、过期的、重复的 → 赶紧扔

只返回JSON,不要markdown代码块:
{"discardScore":数字,"reason":"一句话理由","suggestion":"keep/consider/discard"}`,
          },
          {
            role: 'user',
            content: `物品：${item.name}\n分类：${item.category}\n预估价值：¥${item.estimatedPrice ?? '未知'}\n成色：${item.condition}`,
          },
        ],
      }

      const response = await fetchWithRetry(body, apiKey)

      if (!response.ok) {
        const bodyText = await response.text()
        if (response.status === 401) throw new Error('API Key 无效，请在设置中更新')
        if (response.status === 402) throw new Error('API 账户余额不足，请充值后重试')
        if (response.status === 422) throw new Error('请求参数错误，请联系开发者')
        if (response.status === 429) throw new Error('请求太频繁，请稍后重试')
        throw new Error(`AI 服务错误 (${response.status})`)
      }

      const json = await response.json()
      const content: string = json.choices?.[0]?.message?.content ?? ''

      const parsed = parseJSONFromContent(content)
      return validateDiscardJudgment(parsed)
    } catch (err) {
      if (err instanceof SyntaxError) {
        const msg = 'AI 返回格式异常，请重试（如重复出现请重拍照片）'
        setError(msg)
        throw new Error(msg)
      }
      const msg = err instanceof Error ? err.message : '未知错误'
      setError(msg)
      throw err
    } finally {
      setLoading(false)
    }
  }

  return {
    analyzePhoto: analyzePhotoStream,
    analyzePhotoBatch,
    judgeItem,
    loading,
    error,
    hasKey: !!apiKey,
    apiKey,
    saveApiKey,
    clearApiKey,
  }
}
