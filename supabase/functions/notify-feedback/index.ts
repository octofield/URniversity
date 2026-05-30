import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const TO_EMAIL = Deno.env.get('FEEDBACK_EMAIL') ?? ''

function formatGmt8(isoString: string): string {
  const d = new Date(isoString)
  const gmt8 = new Date(d.getTime() + 8 * 60 * 60 * 1000)
  return gmt8.toISOString().replace('T', ' ').slice(0, 19)
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  const payload = await req.json()
  const record = payload.record

  const typeLabel = record.type === 'bug' ? '問題回報' : '功能建議'
  const time = formatGmt8(record.created_at)

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'URniversity <onboarding@resend.dev>',
      to: [TO_EMAIL],
      subject: `[URniversity 回饋] ${typeLabel}`,
      text: `類型：${typeLabel}\n\n${record.message}\n\n時間：${time} (GMT+8)`,
    }),
  })

  if (!res.ok) {
    const body = await res.text()
    console.error('Resend error:', body)
    return new Response(body, { status: 500 })
  }

  return new Response('ok', { status: 200 })
})
