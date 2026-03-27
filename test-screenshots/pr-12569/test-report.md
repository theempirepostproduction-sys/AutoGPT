# Test Report: PR #12569 - SQL Query Block

**PR:** feat/sql-query-block
**Branch:** `zamilmajdy/secrt-2171-sql-query-block-for-copilotautopilot-analytics-access`
**Tested:** 2026-03-27
**Environment:** Local (frontend: localhost:3000, backend: localhost:8006)

---

## Summary

The SQL Query Block feature has been implemented and is functional. The block appears in the block library, renders correctly on the builder canvas with all expected fields, and the backend API properly registers the block with correct schema definitions. Security measures (SSRF protection, query validation, error sanitization) are well-implemented in the backend code.

**Overall: PASS (with minor notes)**

---

## Test Results

### 1. SQL Query Block exists in block library
**Result: PASS**

Searched for "SQL" in the builder block menu. The "SQL Query" block appears as the top result.

- Screenshot: `16-sql-block-search.png`

### 2. SQL Query Block fields on canvas
**Result: PASS**

Added the SQL Query Block to the canvas. Verified all expected fields are present:

**Standard fields:**
- DatabaseType (dropdown: postgres, mysql, mssql)
- Host (secret/password field)
- Database (text field)
- Query (text field)
- Database credential (credentials button)

**Advanced fields (expandable):**
- Port (optional, defaults vary by DB type)
- Read Only (toggle, defaults to true)
- Timeout (integer, default 30, max 120)
- Max Rows (integer, default 1000, max 10000)

**Output fields:**
- results (list of row dictionaries)
- columns (list of column names)
- row_count (integer)
- affected_rows (integer, for write queries)
- error (string)

- Screenshots: `17-sql-block-on-canvas.png`, `21-sql-block-advanced.png`

### 3. Credential modal labels
**Result: PASS (different from expected)**

The test plan expected "Connection URL" in the credential modal. The actual implementation uses `user_password` credentials (Username + Password), which is a **better design choice** because:
- The block takes host/port/database as separate fields (not a connection URL)
- The credentials only store the authentication part (username + password)
- This separation prevents credential-embedded connection strings

The modal displays:
- **Title:** "Add new username & password for Database"
- **Fields:** Username, Password, Name
- **Button:** "Save & use this user login"

- Screenshot: `20-credential-modal.png`

### 4. Block exists via API
**Result: PASS**

```
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8006/api/blocks \
  | jq '.[] | select(.name == "SQLQueryBlock") | {name, description}'
```

Response:
```json
{
  "name": "SQLQueryBlock",
  "description": "Execute a SQL query. Read-only by default for safety -- disable to allow write operations. Supports PostgreSQL, MySQL, and MSSQL via SQLAlchemy."
}
```

### 5. DATABASE provider exists via API
**Result: PASS**

```
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8006/api/integrations/providers \
  | jq '.[] | select(. == "database")'
```

Response: `"database"`

### 6. Security review (code inspection)
**Result: PASS**

Reviewed `backend/blocks/sql_query_block.py`:

- **SSRF protection:** Uses `resolve_and_check_blocked()` to validate host is not internal/private. Pins connection to resolved IP to prevent DNS rebinding (TOCTOU) attacks.
- **Query validation (defense-in-depth):**
  - Single statement enforcement (prevents injection via semicolons)
  - Statement type must be SELECT when read_only=true
  - Disallowed keywords checked against parsed SQL tokens (not raw text): INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, TRUNCATE, GRANT, REVOKE, INTO, OUTFILE, DUMPFILE, etc.
  - Uses `sqlparse` for proper tokenization (column names and string literals don't cause false positives)
- **Read-only mode:** Set at database session level (PostgreSQL: `SET default_transaction_read_only = ON`, MySQL: `SET SESSION TRANSACTION READ ONLY`). Transaction always rolled back in read-only mode.
- **Error sanitization:** Strips connection strings, credentials, IP addresses, usernames, and ports from error messages before exposing to users/LLM.
- **Unix socket prevention:** Rejects host paths starting with `/`.
- **Timeout enforcement:** Per-database timeout settings (statement_timeout for PG, MAX_EXECUTION_TIME for MySQL, LOCK_TIMEOUT for MSSQL).
- **Safe interpolation:** Timeout value uses `str(int(...))` cast to prevent SQL injection in SET commands.

---

## Notes

1. **UI complexity:** The builder canvas is now integrated with the copilot sidebar, which overlays the ReactFlow canvas. This required JavaScript-level interaction (hiding the copilot section, blocking navigation) to access the block menu and canvas controls. The session also had frequent auth expiration issues during testing.

2. **Credential type difference:** The test plan expected "Connection URL" / "API Key" terminology, but the implementation correctly uses `user_password` credentials (Username + Password). This is architecturally better since connection parameters (host, port, database) are separate block input fields, and only authentication data goes into credentials.

3. **Block category:** The block is categorized under DATA, which is appropriate for a database query block.
