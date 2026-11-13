import { optional } from './env'

/**
 * Yu AI (api.yuai.dev, sub2api) as the one model provider of this fork's OpenCode runtimes.
 * The backend proxies each turn to it with the acting user's own Yu AI key, looked up through
 * sub2api's admin API by the user's email (both sign in through the same Logto).
 */
export function yuaiConfig() {
  return {
    apiUrl: (optional('YUAI_API_URL') ?? 'https://api.yuai.dev').replace(/\/$/, ''),
    // sub2api's global admin API key; without it the proxy answers 503.
    adminKey: optional('YUAI_ADMIN_KEY'),
    // A user's active key with this name wins; otherwise their newest active key.
    keyName: optional('YUAI_KEY_NAME') ?? 'nuphos',
  }
}
