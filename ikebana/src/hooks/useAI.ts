import { useState } from 'react'
import type { Item } from '../data/mock'
import { categories } from '../data/mock'

const API_KEY_STORAGE = 'ikebana_api_key'

export interface ItemFormData {
  name: string
  category: string
  stored: string
  purchaseDate?: string
  lastUsedDate?: string
  useCount?: number
  userRating?: number
  purchasePrice?: number
  userNotes?: string
}

export interface QuickParseResult {
  name: string
  category: string
  stored: string
  purchasePrice?: number
  purchaseDate?: string
  userNotes?: string
}

export interface AIResult {
  suggestedAction: 'keep' | 'discard' | 'consider'
  reason: string
  coachLine: string
  quality: 'good' | 'fair' | 'poor'
}

function buildPrompt(data: ItemFormData): string {
  const today = new Date()

  const ageDays = data.purchaseDate
    ? Math.floor((today.getTime() - new Date(data.purchaseDate).getTime()) / 86400000)
    : null

  const unusedDays = data.lastUsedDate
    ? Math.floor((today.getTime() - new Date(data.lastUsedDate).getTime()) / 86400000)
    : null

  const parts: string[] = [
    `物品：${data.name}`,
    `分类：${data.category}`,
    `存放位置：${data.stored}`,
  ]
  if (ageDays !== null) parts.push(`购买于约 ${ageDays} 天前`)
  if (unusedDays !== null) parts.push(`上次使用距今 ${unusedDays} 天`)
  else parts.push('不确定上次使用时间')
  if (data.useCount !== undefined) parts.push(`累计使用约 ${data.useCount} 次`)
  if (data.userRating !== undefined) parts.push(`用户满意度：${data.userRating}/5 星`)
  if (data.purchasePrice) parts.push(`购入价格：¥${data.purchasePrice}`)
  if (data.userNotes) parts.push(`用户自己说："${data.userNotes}"`)

  return `根据以下物品信息，给出断舍离建议：

${parts.join('，')}。

请返回 JSON（只返回 JSON，不要任何其他内容，不要 markdown 代码块）：
{
  "suggestedAction": "discard 或 consider 或 keep",
  "quality": "good 或 fair 或 poor（根据使用年限和评价判断品质）",
  "reason": "客观分析为什么该清理/保留，2-3句，中文",
  "coachLine": "教练风格的一句话，直接推人一把，有态度但不刻薄，中文"
}`
}

export function useAI() {
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

  const analyzeItem = async (data: ItemFormData): Promise<AIResult> => {
    if (!apiKey) throw new Error('未配置 API Key')

    setLoading(true)
    setError(null)

    try {
      const response = await fetch('/api/deepseek/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          max_tokens: 512,
          messages: [
            { role: 'system', content: '你是一位热血的断舍离教练，说话直接、有态度、偶尔幽默。请只返回 JSON，不要任何其他内容，不要 markdown 代码块。' },
            { role: 'user', content: buildPrompt(data) },
          ],
        }),
      })

      if (!response.ok) {
        const body = await response.text()
        if (response.status === 401) throw new Error('API Key 无效，请检查后重试')
        if (response.status === 429) throw new Error('请求太频繁，稍等一下再试')
        throw new Error(`请求失败 (${response.status})：${body.slice(0, 100)}`)
      }

      const json = await response.json()
      const text: string = json.choices?.[0]?.message?.content ?? ''

      // 尝试解析 JSON，容忍 Claude 偶尔带 markdown 代码块
      const cleaned = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()
      const result = JSON.parse(cleaned) as AIResult

      if (!['keep', 'discard', 'consider'].includes(result.suggestedAction)) {
        throw new Error('AI 返回格式不符，请重试')
      }

      return result
    } catch (err) {
      const msg = err instanceof Error ? err.message : '未知错误'
      setError(msg)
      throw err
    } finally {
      setLoading(false)
    }
  }

  const buildItemFromForm = (
    data: ItemFormData,
    aiResult?: AIResult
  ): Omit<Item, 'id'> => {
    const today = new Date()
    const unusedDays = data.lastUsedDate
      ? Math.floor((today.getTime() - new Date(data.lastUsedDate).getTime()) / 86400000)
      : 9999

    return {
      name: data.name,
      category: data.category,
      stored: data.stored,
      daysSinceUsed: unusedDays,
      reason: aiResult?.reason ?? '用户手动录入',
      quality: aiResult?.quality ?? 'good',
      suggestedAction: aiResult?.suggestedAction ?? 'consider',
      coachLine: aiResult?.coachLine,
      purchaseDate: data.purchaseDate,
      lastUsedDate: data.lastUsedDate,
      useCount: data.useCount,
      userRating: data.userRating,
      purchasePrice: data.purchasePrice,
      userNotes: data.userNotes,
      isUserAdded: true,
    }
  }

  const quickParseItem = async (text: string): Promise<QuickParseResult> => {
    if (!apiKey) throw new Error('未配置 API Key')

    setLoading(true)
    setError(null)

    const catList = categories.join('/')

    try {
      const response = await fetch('/api/deepseek/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          max_tokens: 256,
          messages: [
            {
              role: 'system',
              content: `你是物品信息提取器。从用户的口语描述中提取结构化字段。只返回 JSON，不要任何其他内容。`,
            },
            {
              role: 'user',
              content: `从这段话中提取物品信息：${text}

分类必须是以下之一：${catList}

返回 JSON：
{
  "name": "物品名称",
  "category": "${catList}之一，根据物品类型推断",
  "stored": "存放位置，未提及则填'未指定'",
  "purchasePrice": 数字或null,
  "purchaseDate": "YYYY-MM-DD或null（如'两年前买的'→大致推算，'去年'→大致推算）",
  "userNotes": "补充信息或null"
}`,
            },
          ],
        }),
      })

      if (!response.ok) {
        if (response.status === 401) throw new Error('API Key 无效')
        throw new Error(`请求失败 (${response.status})`)
      }

      const json = await response.json()
      const raw: string = json.choices?.[0]?.message?.content ?? ''
      const cleaned = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()
      const result = JSON.parse(cleaned) as QuickParseResult

      if (!result.name) throw new Error('AI 未能提取物品名称，请手动录入')
      if (!categories.includes(result.category)) result.category = '杂物'
      if (!result.stored) result.stored = '未指定'

      return result
    } catch (err) {
      const msg = err instanceof Error ? err.message : '未知错误'
      setError(msg)
      throw err
    } finally {
      setLoading(false)
    }
  }

  const batchParseItems = async (text: string): Promise<QuickParseResult[]> => {
    if (!apiKey) throw new Error('未配置 API Key')
    if (!text.trim()) return []

    setLoading(true)
    setError(null)

    const catList = categories.join('/')

    try {
      const response = await fetch('/api/deepseek/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          max_tokens: 1024,
          messages: [
            {
              role: 'system',
              content: `你是物品信息批量提取器。用户会提供多行文本，每行描述一件物品。提取每件物品的结构化字段。只返回 JSON 数组，不要任何其他内容。`,
            },
            {
              role: 'user',
              content: `从以下多行文本中提取每件物品的信息。每行一个物品：

${text}

分类必须是以下之一：${catList}

返回 JSON 数组：
[{
  "name": "物品名称",
  "category": "${catList}之一",
  "stored": "存放位置，未提及则填'未指定'",
  "purchasePrice": 数字或null,
  "purchaseDate": "YYYY-MM-DD或null",
  "userNotes": "补充信息或null"
}]`,
            },
          ],
        }),
      })

      if (!response.ok) {
        if (response.status === 401) throw new Error('API Key 无效')
        throw new Error(`请求失败 (${response.status})`)
      }

      const json = await response.json()
      const raw: string = json.choices?.[0]?.message?.content ?? ''
      const cleaned = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()
      const results = JSON.parse(cleaned) as QuickParseResult[]

      if (!Array.isArray(results) || results.length === 0) {
        throw new Error('AI 未能提取物品，请检查输入格式')
      }

      return results.map((r) => {
        if (!r.name) r.name = '未命名物品'
        if (!categories.includes(r.category)) r.category = '杂物'
        if (!r.stored) r.stored = '未指定'
        return r
      })
    } catch (err) {
      const msg = err instanceof Error ? err.message : '未知错误'
      setError(msg)
      throw err
    } finally {
      setLoading(false)
    }
  }

  return {
    apiKey,
    saveApiKey,
    clearApiKey,
    analyzeItem,
    quickParseItem,
    batchParseItems,
    buildItemFromForm,
    loading,
    error,
    hasKey: !!apiKey,
  }
}
