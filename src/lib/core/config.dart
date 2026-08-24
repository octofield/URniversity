// The anon key below is a Supabase *publishable* key: it is designed to ship
// inside the client, and the security boundary is Row Level Security, not
// keeping this string secret. Both values stay overridable with --dart-define
// for a different project, but dropping the defaults would mean passing them on
// every flutter run
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://upygftobsmscfjurqhhh.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_oMYt15IZZdfNFfURElZ-bQ_XS1P6RZX',
  );
}
