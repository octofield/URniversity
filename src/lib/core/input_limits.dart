// Every cap on what the user can type, in one place.
//
// The persisted ones are mirrored as CHECK constraints in
// supabase/input_length_limits.sql — change a number here and there together,
// or the database will reject what the app lets through
class InputLimits {
  // ── Persisted (also enforced by the database) ─────────────────────────────
  // Tasks, targets, visions and inspirations
  static const title = 100;
  // Task content, target and vision notes, inspiration details
  static const body = 500;
  static const journal = 5000;
  static const username = 30;
  // A school or department typed in because it is not in the list
  static const customPicker = 50;
  // A course's teacher and a session's classroom
  static const teacher = 50;
  static const location = 50;
  // "CSIE1212", a serial number, a course id
  static const courseCode = 20;

  // ── Persisted inside JSON, so only the app enforces them ──────────────────
  static const categoryName = 20;

  // ── Never stored, or stored by Supabase Auth ──────────────────────────────
  static const search = 50;
  // The longest address RFC 5321 allows
  static const email = 254;
  // bcrypt, which Supabase Auth hashes with, ignores everything past 72 bytes
  static const password = 72;
  // Digits in "every N days"
  static const repeatIntervalDigits = 3;
  // "#RRGGBB"
  static const hexColor = 7;
  static const feedback = 1000;
}
