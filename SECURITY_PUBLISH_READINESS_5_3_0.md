# ALIN 5.3.0 Security & Publish Readiness

Applied to production Supabase on 2026-08-19:
- Student sessions are bounded to 30 days.
- In-app account deletion requires the student PIN.
- Terminal orders are anonymized on account deletion. Active fulfillment retains only operational data until terminal status, then is anonymized automatically.
- Public/anon EXECUTE grants were removed from internal SECURITY DEFINER helper/trigger functions.
- External account-deletion request endpoint deployed with generic responses and rate limiting.
- Privacy policy and account-deletion public pages added.
- Flutter version: 5.3.0+5.
- Signed GitHub artifact: alin-flutter-v5.3.0-build5-SECURITY-SIGNED.

Do not place Android signing keys or passwords in this repository. Keep them only in GitHub Actions Secrets and offline backup.
