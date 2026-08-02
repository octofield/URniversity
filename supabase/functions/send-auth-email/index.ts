import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Webhook } from 'npm:standardwebhooks@1.0.0'

const HOOK_SECRET = Deno.env.get('SEND_EMAIL_HOOK_SECRET') ?? ''
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''

interface EmailData {
  token_hash: string
  redirect_to: string
  email_action_type: string
}

function subjectFor(type: string): string {
  switch (type) {
    case 'signup':       return '請驗證你的 URniversity 帳號'
    case 'recovery':      return 'URniversity 密碼重設'
    case 'email_change':  return 'URniversity 電子郵件變更確認'
    case 'invite':        return 'URniversity 邀請你加入'
    case 'magiclink':     return 'URniversity 登入連結'
    default:               return 'URniversity 帳號驗證'
  }
}

function bodyFor(type: string, confirmationUrl: string): string {
  const action = type === 'recovery' ? '重設密碼' : type === 'email_change' ? '確認新的電子郵件' : '驗證帳號'
  return `
    <p>請點擊以下連結完成${action}：</p>
    <p><a href="${confirmationUrl}">${confirmationUrl}</a></p>
    <p>如果這不是你本人的操作，請忽略這封信。</p>
  `
}

serve(async (req) => {
  const payload = await req.text()
  const headers = Object.fromEntries(req.headers)

  let data: { user: { email: string }; email_data: EmailData }
  try {
    const wh = new Webhook(HOOK_SECRET)
    data = wh.verify(payload, headers) as typeof data
  } catch (error) {
    console.error('Webhook verification failed:', error)
    return new Response(
      JSON.stringify({ error: { http_code: 401, message: 'Invalid signature' } }),
      { status: 401 },
    )
  }

  const { user, email_data } = data
  const { token_hash, redirect_to, email_action_type } = email_data

  const confirmationUrl =
    `${SUPABASE_URL}/auth/v1/verify?token=${token_hash}&type=${email_action_type}&redirect_to=${redirect_to}`

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'URniversity <onboarding@resend.dev>',
      to: [user.email],
      subject: subjectFor(email_action_type),
      html: bodyFor(email_action_type, confirmationUrl),
    }),
  })

  if (!res.ok) {
    const body = await res.text()
    console.error('Resend error:', body)
    return new Response(
      JSON.stringify({ error: { http_code: 500, message: 'Failed to send email' } }),
      { status: 500 },
    )
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
