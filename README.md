# mmc_app

MMC uses Supabase for realtime messages and file attachments.

## Supabase setup

1. Create a Supabase project.
2. Open **SQL Editor** and run [`supabase_schema.sql`](supabase_schema.sql).
3. Copy the project URL and publishable/anon key from **Project Settings > API**.

Run the app with:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

The URL and publishable key are safe for the client app. Never put a Supabase service-role key in Flutter code.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
