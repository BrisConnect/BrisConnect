# User Story Walkthrough: Admin Secure Login

This picture represents the in-app flow for the user story:

"As an Admin, I want to log in securely so that I can manage platform operations."

Implementation references in the app:

- `lib/screens/admin_login_screen.dart`
- `lib/auth/admin_auth.dart`
- `lib/services/role_access_service.dart`
- `lib/main.dart` route: `/admin/login`

## Picture (App Flow)

```mermaid
flowchart TD
    A([App Start]) --> B[Open Admin Login Screen\n/admin/login]
    B --> C[Enter Username or Email\nand Password]
    C --> D{Tap Login}

    D --> E{Credentials Valid?}
    E -- No --> F[Show Clear Error Message\nInvalid credentials or auth error]
    F --> C

    E -- Yes --> G{Role = Admin?}
    G -- No --> H[Access Denied\nNon-admin blocked from admin screens]
    H --> B

    G -- Yes --> I[Create Auth Session\nUpdate lastLoginAt]
    I --> J[Redirect to Admin Dashboard]

    K[[Protected Admin Route\n/admin/*]] --> L{Authenticated + Admin Role?}
    L -- No --> M[Block Route\nRedirect to Login or Denied Screen]
    L -- Yes --> N[Allow Access]

    style B fill:#fff7e6,stroke:#b36b00,stroke-width:2px
    style F fill:#ffeaea,stroke:#c93a3a,stroke-width:2px
    style H fill:#ffeaea,stroke:#c93a3a,stroke-width:2px
    style J fill:#eaffef,stroke:#1f7a3a,stroke-width:2px
    style M fill:#ffeaea,stroke:#c93a3a,stroke-width:2px
    style N fill:#eaffef,stroke:#1f7a3a,stroke-width:2px
```

## User Steps and Comments

1. User opens the app and navigates to Admin Login.
Comment: Entry point should always be available, but admin areas are still protected by role checks.

2. User enters username/email and password, then taps Login.
Comment: Credentials are validated securely by authentication logic.

3. If credentials are invalid, the app shows a clear error message.
Comment: This satisfies the acceptance criterion for readable failure feedback.

4. If credentials are valid, the app checks whether the authenticated account has Admin role.
Comment: This prevents Local/Visitor users from entering admin-only screens.

5. If role is not Admin, access is denied and protected routes remain inaccessible.
Comment: Route guards and role checks enforce authorization boundaries.

6. If role is Admin, user is redirected to the Admin Dashboard.
Comment: Successful login path meets dashboard redirection requirement.

7. For every `/admin/*` route access, the app re-validates auth + role.
Comment: Protection applies both at login and at route access time for reliability.
