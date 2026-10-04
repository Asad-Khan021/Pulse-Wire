-- ==============================================================================
-- Digest Platform — Row-Level Security (RLS) Configuration
-- Supabase / PostgreSQL Direct Migration Script
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Table: user_preferences
-- Enforces that users can only read, insert, and update their own preferences.
-- ------------------------------------------------------------------------------
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_preferences_select_own ON user_preferences;
CREATE POLICY user_preferences_select_own ON user_preferences
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_insert_own ON user_preferences;
CREATE POLICY user_preferences_insert_own ON user_preferences
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_update_own ON user_preferences;
CREATE POLICY user_preferences_update_own ON user_preferences
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Note: No DELETE policy defined intentionally. Preferences are upserted.


-- ------------------------------------------------------------------------------
-- 2. Table: bookmarks
-- Enforces that users can only read, add, and delete their own saved bookmarks.
-- ------------------------------------------------------------------------------
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bookmarks_select_own ON bookmarks;
CREATE POLICY bookmarks_select_own ON bookmarks
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS bookmarks_insert_own ON bookmarks;
CREATE POLICY bookmarks_insert_own ON bookmarks
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS bookmarks_delete_own ON bookmarks;
CREATE POLICY bookmarks_delete_own ON bookmarks
    FOR DELETE
    USING (auth.uid() = user_id);


-- ------------------------------------------------------------------------------
-- 3. Public Read Tables: sources, articles, summaries, signals
-- Read-only for authenticated & anonymous clients; write access restricted
-- to the backend service role connection.
-- ------------------------------------------------------------------------------
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE signals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sources_public_read ON sources;
CREATE POLICY sources_public_read ON sources
    FOR SELECT USING (true);

DROP POLICY IF EXISTS articles_public_read ON articles;
CREATE POLICY articles_public_read ON articles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS summaries_public_read ON summaries;
CREATE POLICY summaries_public_read ON summaries
    FOR SELECT USING (true);

DROP POLICY IF EXISTS signals_public_read ON signals;
CREATE POLICY signals_public_read ON signals
    FOR SELECT USING (true);

-- No INSERT / UPDATE / DELETE policies for authenticated role on these tables.
-- PostgreSQL default DENY ensures only the backend service role can ingest or generate.
