# BrisConnect User Stories Link Diagram

This diagram links all documented BrisConnect stories (1-55) into role groups and
end-to-end feature flows.

```mermaid
flowchart LR
  classDef admin fill:#fde7e9,stroke:#b4232f,color:#4a1116,stroke-width:1px;
  classDef local fill:#fff2db,stroke:#b96b00,color:#4a2b00,stroke-width:1px;
  classDef visitor fill:#e8f3ff,stroke:#1263b3,color:#0f2942,stroke-width:1px;
  classDef shared fill:#e8f8ef,stroke:#1f8a4c,color:#153922,stroke-width:1px;
  classDef platform fill:#f4f0ff,stroke:#5a3ab0,color:#2b1f55,stroke-width:1px;

  subgraph Admin[Admin Stories]
    A1["1 Admin Secure Login"]
    A2["2 Dashboard Metrics"]
    A3["3 Review Local Accounts"]
    A4["4 Moderate Events"]
    A5["5 Manage Attractions"]
    A37["37 Manage All Users"]
    A38["38 Review Reported Events"]
    A39["39 Review App Feedback"]
    A40["40 SMS Broadcast"]
    A41["41 Edit Event Details"]
  end

  subgraph Local[Local Stories]
    L6["6 Local Login"]
    L7["7 Account Approval Notifications"]
    L8["8 Submit Event With Media"]
    L9["9 Edit Own Submitted Events"]
    L10["10 Event Review Notifications"]
    L11["11 Manage Local Profile"]
    L42["42 Local Registration"]
    L45["45 Profile Readability"]
    L46["46 Full-Screen Kookaburra Background"]
    L47["47 Seamless AppBar Over Background"]
  end

  subgraph Visitor[Visitor Stories]
    V12["12 Visitor Login"]
    V13["13 Browse Approved Events"]
    V14["14 Event Detail Pages"]
    V15["15 Report Problematic Events"]
    V16["16 Saved Events Calendar"]
    V17["17 View Attraction Details"]
    V18["18 Attraction Accessibility"]
    V19["19 Manage Visitor Profile"]
    V43["43 Visitor Registration"]
    V44["44 Interested Events List"]
    V50["50 Personalized Event Recommendations"]
    V51["51 Multi-Filter Discover Results"]
  end

  subgraph Shared[Shared Stories]
    S20["20 Event Audio Guide"]
    S21["21 Attraction Audio Guide"]
    S22["22 Notification History"]
    S23["23 Notification Settings"]
    S24["24 Approved Attractions Map"]
    S25["25 Events/Attractions Map"]
    S26["26 Live GPS Tracking"]
    S27["27 Welcome Screen"]
    S28["28 Login Role Selection"]
    S29["29 Register Role Selection"]
    S30["30 Interest Categories"]
    S31["31 Location Settings"]
    S32["32 Theme and Text Size"]
    S33["33 Browse Brisbane Stories"]
    S34["34 Food Place Details"]
    S35["35 Stadium/Venue Details"]
    S36["36 Submit App Feedback"]
    S48["48 Auto-Hide Bottom Navigation"]
    S49["49 Debounced Multi-Field Search"]
    S52["52 Image Placeholder and Fallback"]
    S53["53 AI Audio Narration en-AU"]
    S54["54 Offline Mode and Auto-Reconnect"]
    S55["55 Immersive Cultural Welcome Screen"]
  end

  subgraph Platform[Core Platform Flows]
    PAuth["Authentication and Role Guard"]
    PEvent["Event Lifecycle"]
    PNotify["Notifications and Messaging"]
    PMap["Map and Location Experience"]
    PContent["Discovery Content"]
    PQuality["Feedback and Moderation"]
  end

  S27 --> S28 --> A1
  S27 --> S28 --> L6
  S27 --> S28 --> V12
  S27 --> S29 --> L42
  S27 --> S29 --> V43
  S55 --> S28

  L42 --> A3 --> L7
  L6 --> L8 --> A4 --> L10
  L8 --> L9 --> A41
  L6 --> L45 --> L46 --> L47
  V12 --> V13 --> V14
  V14 --> V15 --> A38
  V13 --> V16
  V13 --> V44
  V13 --> V50
  V50 --> V51

  A5 --> V17 --> V18
  V17 --> S21
  V14 --> S20
  S33 --> S34
  S33 --> S35
  S52 --> V13
  S52 --> S33
  S53 --> S20
  S53 --> S21

  V12 --> S30
  L6 --> S30
  S30 --> V13
  S30 --> L8
  S49 --> V13
  S49 --> S25
  S48 --> V13
  S48 --> L6
  S31 --> S25
  S26 --> S25
  S24 --> S25
  V51 --> S25

  S36 --> A39
  A2 --> A38
  A2 --> A39
  A37 --> A3
  A37 --> A40
  L7 --> S22
  L10 --> S22
  V16 --> S22
  S23 --> S22

  A1 --> PAuth
  L6 --> PAuth
  V12 --> PAuth
  L8 --> PEvent
  A4 --> PEvent
  V13 --> PEvent
  L7 --> PNotify
  L10 --> PNotify
  S22 --> PNotify
  S25 --> PMap
  S26 --> PMap
  S49 --> PMap
  S33 --> PContent
  S34 --> PContent
  S35 --> PContent
  V50 --> PContent
  V51 --> PContent
  S52 --> PContent
  S54 --> PNotify
  S55 --> PAuth
  S36 --> PQuality
  A38 --> PQuality
  A39 --> PQuality

  class A1,A2,A3,A4,A5,A37,A38,A39,A40,A41 admin;
  class L6,L7,L8,L9,L10,L11,L42,L45,L46,L47 local;
  class V12,V13,V14,V15,V16,V17,V18,V19,V43,V44,V50,V51 visitor;
  class S20,S21,S22,S23,S24,S25,S26,S27,S28,S29,S30,S31,S32,S33,S34,S35,S36,S48,S49,S52,S53,S54,S55 shared;
  class PAuth,PEvent,PNotify,PMap,PContent,PQuality platform;
```

## Source

- Story list and IDs: [All_User_Stories_Traceability.md](../All_User_Stories_Traceability.md)
- Supplemental story set: [BrisConnect_Jira_User_Stories.md](../BrisConnect_Jira_User_Stories.md)