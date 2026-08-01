# Activity Diagram: Share Events and Business Listings on Social Media

## User Story

**As a** Visitor,  
**I want to** share events and business listings to social media,  
**So that** I can recommend them to friends and family.

## Improved Acceptance Criteria

- Visitors can share **events** and **business listings** from their detail pages.
- Supported platforms: **Facebook**, **Instagram**, and **TikTok**.
- Shared content includes the **latest title, image, and description** from the listing.
- The share preview loads **instantly** when the share button is tapped.
- The sharing process completes **without errors** on supported platforms.
- A clear **success** or **failure** message appears after each sharing attempt.
- Sharing works across **mobile and desktop** devices.
- The app supports the latest stable versions of Facebook, Instagram, and TikTok apps/APIs.
- Shared content always reflects the **latest event/business data**.
- Shared links are **valid, unbroken, and tamper-proof**.
- The sharing feature is available **24/7 with 99.9% uptime**.
- The system handles **high-volume sharing** during popular events without delay.

## Activity Diagram

```mermaid
flowchart TB
    Start([Visitor opens business or event page]) --> ViewContent[View event or business listing]
    ViewContent --> ShareButton[Share button visible]

    ShareButton --> TapShare[Tap share button]
    TapShare --> DetectPlatform{Detect device platform}

    DetectPlatform -->|Mobile| NativeFlow[Open native share sheet or platform app]
    DetectPlatform -->|Desktop| WebFlow[Open platform web share dialog]

    NativeFlow --> FetchMetadata[Fetch latest title, image, and description]
    WebFlow --> FetchMetadata

    FetchMetadata --> MatchCheck{Data matches current listing?}

    MatchCheck -->|No| RefreshData[Refresh data from server]
    RefreshData --> FetchMetadata

    MatchCheck -->|Yes| GenerateLink[Generate secure shareable link]
    GenerateLink --> ValidateLink{Link valid and not broken?}

    ValidateLink -->|No| RegenerateLink[Regenerate link]
    RegenerateLink --> GenerateLink

    ValidateLink -->|Yes| SelectPlatform[Select Facebook, Instagram, or TikTok]

    SelectPlatform --> PlatformCheck{Platform supported?}

    PlatformCheck -->|No| ShowUnsupported[Show unsupported platform message]
    ShowUnsupported --> FallbackShare[Offer native share or copy link]
    FallbackShare --> EndUnsupported([End])

    PlatformCheck -->|Yes| OpenShare[Open selected platform with metadata]

    OpenShare --> ShareResult{Share completed?}

    ShareResult -->|Success| ShowSuccess[Show: "Shared successfully"]
    ShareResult -->|Failure| ShowFailure[Show: "Sharing failed. Try again or copy link."]
    ShareResult -->|Cancelled| EndCancelled([End])

    ShowSuccess --> TrackAnalytics[Track share analytics]
    ShowFailure --> OfferRetry{Retry?}
    OfferRetry -->|Yes| SelectPlatform
    OfferRetry -->|No| EndFailure([End])

    TrackAnalytics --> EndSuccess([End])

    subgraph UptimeMonitoring ["Uptime Monitoring"]
        Monitor[Monitor sharing feature uptime] --> UptimeCheck{Available ≥ 99.9%?}
        UptimeCheck -->|Yes| Continue[Continue monitoring]
        UptimeCheck -->|No| EnableFallback[Enable cached fallback]
        EnableFallback --> AlertOps[Alert operations team]
        AlertOps --> Continue
    end

    subgraph ScalabilityMonitoring ["Scalability Monitoring"]
        TrafficCheck{High sharing volume?} -->|Yes| ScaleResources[Auto-scale share service]
        ScaleResources --> ContinueScale[Continue monitoring]
        TrafficCheck -->|No| ContinueScale
    end
```

## Diagram Explanation

1. **Open business or event page** — Visitor views a listing they want to share.
2. **Tap share button** — Visitor initiates sharing.
3. **Detect device platform** — The app chooses the mobile native flow or desktop web flow.
4. **Fetch metadata** — Latest title, image, and description are retrieved.
5. **Data match check** — Ensures shared content reflects the most current listing data.
6. **Generate link** — A secure, unique shareable link is created.
7. **Link validation** — Confirms the link is valid and not broken.
8. **Select platform** — Visitor chooses Facebook, Instagram, or TikTok.
9. **Platform support check** — Unsupported platforms trigger a fallback option.
10. **Open share dialog** — The selected platform receives the metadata and link.
11. **Share result** — The app detects success, failure, or cancellation.
12. **Success/failure feedback** — Visitor sees a clear message and can retry if needed.
13. **Analytics tracking** — Successful shares are logged.
14. **Uptime monitoring** — The feature is monitored for 99.9% availability; fallback and alerting activate if it drops.
15. **Scalability monitoring** — Resources auto-scale during high-volume sharing periods such as popular events.
