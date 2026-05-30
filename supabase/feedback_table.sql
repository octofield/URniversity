CREATE TABLE feedbacks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type text NOT NULL CHECK (type IN ('bug', 'suggestion')),
  message text NOT NULL CHECK (char_length(message) >= 10 AND char_length(message) <= 1000),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- Anyone (including anonymous users) can submit feedback, but cannot read others'
CREATE POLICY "allow_insert" ON feedbacks
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);
