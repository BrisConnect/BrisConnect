# Local Login: Sequence Diagram and SQL Query Pack

User story:
As a Local user, I want to log in to my account so that I can access local portal features.

## Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor U as Local User
    participant APP as Mobile App
    participant API as Auth API
    participant DB as MySQL
    participant GUARD as Route Guard

    U->>APP: Enter email or username + password
    APP->>API: POST /auth/local/login
    API->>DB: Fetch auth_users by email or username
    DB-->>API: user record + password_hash + status

    alt Invalid credentials or locked account
        API->>DB: INSERT login_attempts(was_successful=0, failure_reason)
        API-->>APP: 401/423 with clear feedback message
        APP-->>U: Show error and allow retry
    else Valid local credentials
        API->>DB: Validate local role via user_roles + roles
        alt Wrong role
            API->>DB: INSERT login_attempts(was_successful=0, failure_reason='wrong_role')
            API-->>APP: 403 Access denied for local portal
            APP-->>U: Show non-local access blocked message
        else Local role confirmed
            API->>DB: INSERT auth_sessions(session/refresh hashes, expiry)
            API->>DB: UPDATE auth_users last_login_at, reset failed_login_count
            API->>DB: INSERT login_attempts(was_successful=1)
            API-->>APP: 200 Login success + tokens
            APP-->>U: Redirect to Local Portal
        end
    end

    U->>APP: Reopen app
    APP->>API: POST /auth/session/restore (restore token)
    API->>DB: Lookup auth_sessions by restore_key_hash + expiry + is_revoked=0
    DB-->>API: active session + user_id
    API->>DB: Verify user role local_user
    API-->>APP: 200 session restored
    APP-->>U: Open Local Portal directly

    U->>APP: Open /local/dashboard
    APP->>GUARD: Route access request
    GUARD->>DB: Check route_policies + user permissions
    DB-->>GUARD: allowed or denied
    GUARD-->>APP: allow or block
```

## Steps and Notes

1. Credentials are checked against secure password hashes in auth_users.
2. Invalid credentials write login_attempts and return clear UI feedback.
3. Successful auth still requires local role authorization.
4. Local users receive session tokens and are redirected to local portal.
5. Session restoration uses hashed restore key with expiry and revocation checks.
6. Route guard enforces local-only access for every local route.
