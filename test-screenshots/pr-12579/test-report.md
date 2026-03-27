# Test Report: PR #12579 - fix(copilot): resolve host-scoped credentials for authenticated web requests

**Date:** 2026-03-27
**Tester:** Automated (Claude)
**Branch:** fix/copilot-authenticated-webrequest
**Local servers:** Frontend (http://localhost:3000), Backend (http://localhost:8006)
**Test user:** test@test.com

## Summary

**Result: PASS** -- All 15 new tests pass, no regressions in the full copilot test suite (585 pass, 4 pre-existing failures unrelated to this PR).

## PR Changes Reviewed

### 1. `helpers.py` - `_resolve_discriminated_credentials()`
- **Before:** The condition `if field_info.discriminator and field_info.discriminator_mapping:` excluded host-scoped credentials where `discriminator="url"` but `discriminator_mapping=None`. The URL from `input_data` was never added to `discriminator_values`.
- **After:** Split into nested `if/else` branches:
  - When `discriminator_mapping` exists: provider-based discrimination (unchanged behavior)
  - When `discriminator_mapping` is `None`: URL/host-based discrimination -- deep copies `field_info` and adds the URL to `discriminator_values`
- **Minor cleanup:** Collapsed f-string concatenation in `synthetic_node_exec_id` (cosmetic)
- **Assessment:** Fix is correct and well-documented. The deep copy (`model_copy(deep=True)`) prevents mutating the cached schema-level field_info.

### 2. `model.py` - `CredentialsFieldInfo.discriminate()`
- **Change:** `discriminator_values=self.discriminator_values` -> `discriminator_values=set(self.discriminator_values)`
- **Assessment:** Defensive copy prevents the returned `CredentialsFieldInfo` from sharing the same mutable set with the original. Correct fix.

### 3. `http_credentials_test.py` (new file)
- 15 tests across 4 test classes covering the full stack from discriminator resolution to RunBlockTool end-to-end
- All tests pass

## Test Results

### Unit Tests (15/15 PASS)

| Test Class | Tests | Status |
|---|---|---|
| TestResolveDiscriminatedCredentials | 5 | All PASS |
| TestFindMatchingHostScopedCredential | 5 | All PASS |
| TestResolveBlockCredentials | 3 | All PASS |
| TestRunBlockToolAuthenticatedHttp | 2 | All PASS |

### Full Copilot Test Suite (585/589 PASS)

4 failures are **pre-existing** (confirmed on dev branch):
- `test_chromium_executable_env_is_set` -- environment config issue
- `test_workspace_file_round_trip` -- workspace file test
- `test_read_workspace_file_with_offset_and_length` -- workspace file test
- `test_write_workspace_file_source_path` -- workspace file test

**No regressions introduced by this PR.**

### Backend API Verification

- Backend server healthy (HTTP 200 on /docs)
- `SendWebRequestBlock` (id: 6595ae1f-b924-42cb-9a41-551a0611c4b4) registered and accessible
- `SendAuthenticatedWebRequestBlock` (id: fff86bcd-e001-4bad-a7f6-2eae4720c8dc) registered and accessible
- Both blocks return correct input schemas via `/api/blocks`
- Auth token generation works correctly

### Frontend/CoPilot Browser Testing

- Frontend server healthy (HTTP 200)
- Successfully logged in as test@test.com
- CoPilot home page loads correctly with chat history
- Sent message requesting SendWebRequestBlock execution from within an existing CoPilot chat session
- CoPilot correctly processed the request: showed block schema details ("Details for SendWebRequestBlock"), then proceeded to make the GET request (screenshot #15)
- Note: CoPilot home screen messages trigger the onboarding/agent-creation flow which redirects to agent builder/library. Direct tool execution (run_block) happens within existing chat sessions.

## Code Review Notes

1. **Correctness:** The fix properly handles the case where `discriminator` is set but `discriminator_mapping` is `None` (host-scoped credentials like `SendAuthenticatedWebRequestBlock`). Previously, this case was silently skipped.

2. **Immutability:** Both the `model_copy(deep=True)` in helpers.py and `set(self.discriminator_values)` in model.py correctly prevent mutation of cached schema objects. The test `test_url_discriminator_does_not_mutate_original_field_info` specifically validates this.

3. **URL logging:** URLs are intentionally NOT logged in the host-based branch (only a generic message), while model names ARE logged in the provider-based branch. This is appropriate since URLs may contain sensitive path information.

4. **`is not None` check:** Using `if discriminator_value is not None:` instead of `if discriminator_value:` correctly handles falsy but valid discriminator values (e.g., empty string, 0).

5. **Test coverage:** Comprehensive -- covers URL population, empty URL, mutation prevention, provider preservation, provider-based regression, host matching (correct/wrong/wildcard/multiple), integration with mock credentials, and end-to-end RunBlockTool flows.

## Screenshots

- 01-homepage.png -- CoPilot home page
- 09-dryrun-chat.png -- Existing CoPilot chat with successful tool execution
- 13-dryrun-chat-detail.png -- Dry run chat with block output details
- 14-typed-webrequest.png -- Web request message typed in chat
- 15-webrequest-response.png -- CoPilot processing SendWebRequestBlock (schema fetch + execution)
