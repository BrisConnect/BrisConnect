# User Story Storyboard: Admin Login (Mobile Screen Style)

User story:
As an Admin, I want to log in securely so that I can manage platform operations.

## App Storyboard Picture

```mermaid
flowchart LR
    subgraph S1[Screen 1 - Admin Login]
      A1[BrisConnect Logo]
      A2[Username or Email Field]
      A3[Password Field]
      A4[Login Button]
      A1 --> A2 --> A3 --> A4
    end

    subgraph S2[Screen 2 - Invalid Credentials]
      B1[Admin Login Form]
      B2[Error Banner: Invalid credentials]
      B3[Retry Login]
      B1 --> B2 --> B3
    end

    subgraph S3[Screen 3 - Non-Admin Blocked]
      C1[Authenticated User]
      C2[Role Check Failed]
      C3[Access Denied Message]
      C4[Back to Login or Home]
      C1 --> C2 --> C3 --> C4
    end

    subgraph S4[Screen 4 - Admin Dashboard]
      D1[Authenticated Admin]
      D2[Role Check Passed]
      D3[Admin Dashboard]
      D4[Manage Users / Events / Reports]
      D1 --> D2 --> D3 --> D4
    end

    A4 --> E{Credentials Valid?}
    E -- No --> S2
    E -- Yes --> F{Role is Admin?}
    F -- No --> S3
    F -- Yes --> S4

    G[Protected Route: /admin/*] --> H{Session + Admin Role?}
    H -- No --> C3
    H -- Yes --> D3

    style S1 fill:#fff7e8,stroke:#b66a00,stroke-width:2px
    style S2 fill:#ffecec,stroke:#c43d3d,stroke-width:2px
    style S3 fill:#ffecec,stroke:#c43d3d,stroke-width:2px
    style S4 fill:#ecfff1,stroke:#2b8a4b,stroke-width:2px
```

## User Steps and Comments

1. Open the app and go to Admin Login.
Comment: The entry screen collects admin credentials only.

2. Enter username/email and password, then tap Login.
Comment: Credentials are validated by secure authentication logic.

3. If credentials are invalid, show a clear error message on the same login screen.
Comment: User can immediately correct input and retry.

4. If login succeeds, perform role check before allowing admin navigation.
Comment: Authentication alone is not enough; authorization is mandatory.

5. If the user is not admin, block admin-only screens and show access denied.
Comment: This enforces non-admin restrictions in acceptance criteria.

6. If the user is admin, redirect to Admin Dashboard.
Comment: Successful path satisfies dashboard redirection requirement.

7. On any protected admin route, verify active session and admin role again.
Comment: Route-level guard keeps admin features inaccessible without correct role.
