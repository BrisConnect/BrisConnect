# Activity Diagram: Business Owner — Create and Manage Business Events

## User Story

**As a** Local Food Business owner,  
**I want to** create and manage my business events,  
**So that** I can promote my business activities and keep event information up to date.

## Acceptance Criteria

- Business owner can create an event by entering the event title, date, time, location, description, and optional event image.
- Event title, date, time, and location are required before publishing.
- Published events appear in the event listings.
- Business owner can edit the details of any upcoming event.
- Business owner can cancel or delete an event.
- Updated event information is displayed immediately after saving changes.
- Cancelled events are clearly marked as "Cancelled" or removed from public listings, depending on the system design.
- A confirmation message appears after creating, updating, or cancelling an event.

## Activity Diagram

```mermaid
flowchart TB
    Start([Business owner opens event management]) --> Authenticate{Authenticated as business owner?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| LoadEventDashboard[Load event management dashboard]
    LoadEventDashboard --> ChooseAction{Choose action}

    ChooseAction -->|Create event| CreateEvent[Create new event]
    ChooseAction -->|Edit event| SelectUpcomingEvent[Select upcoming event]
    ChooseAction -->|Cancel / delete| SelectEventToCancel[Select event to cancel or delete]

    CreateEvent --> EnterEventDetails[Enter title, date, time, location, description, optional image]
    SelectUpcomingEvent --> EditEventDetails[Edit event details]

    EnterEventDetails --> ValidateRequiredFields{Required fields filled?<br/>Title, Date, Time, Location}
    EditEventDetails --> ValidateRequiredFields

    ValidateRequiredFields -->|No| ShowValidationError[Show validation error]
    ShowValidationError --> EnterEventDetails

    ValidateRequiredFields -->|Yes| SaveEvent[Save event]
    SaveEvent --> PublishEvent[Publish event]
    PublishEvent --> ShowCreateConfirmation[Show confirmation: "Event created"]
    ShowCreateConfirmation --> DisplayInListings[Display event in public listings]

    EditEventDetails --> SaveChanges[Save changes]
    SaveChanges --> ShowUpdateConfirmation[Show confirmation: "Event updated"]
    ShowUpdateConfirmation --> PushRealtimeUpdate[Push real-time update to listings]

    SelectEventToCancel --> ConfirmCancellation{Confirm cancellation or deletion?}
    ConfirmCancellation -->|No| EndNoAction([End])
    ConfirmCancellation -->|Yes| ApplyCancellation[Cancel or delete event]

    ApplyCancellation --> CancellationDecision{System design?}
    CancellationDecision -->|Mark cancelled| MarkAsCancelled[Mark event as "Cancelled"]
    CancellationDecision -->|Remove listing| RemoveFromListings[Remove event from public listings]

    MarkAsCancelled --> ShowCancelConfirmation[Show confirmation: "Event cancelled"]
    RemoveFromListings --> ShowCancelConfirmation

    ShowCancelConfirmation --> PushRealtimeUpdate
    DisplayInListings --> EndEventManagement([End])
    PushRealtimeUpdate --> EndEventManagement

    subgraph RealTimeSync ["Real-Time Listing Sync"]
        EventChange[Event created, updated, or cancelled] --> BroadcastUpdate[Broadcast update to event listings]
        BroadcastUpdate --> ClientRefresh[Clients refresh event display]
        ClientRefresh --> VisibilityCheck{Information correct?}
        VisibilityCheck -->|No| ReapplyState[Reapply event state]
        ReapplyState --> BroadcastUpdate
        VisibilityCheck -->|Yes| ContinueSync[Continue]
    end
```

## Diagram Explanation

1. **Open event management** — Business owner navigates to the event management section.
2. **Authentication check** — Only authenticated business owners can access event management.
3. **Load dashboard** — The event management dashboard is loaded.
4. **Choose action** — Owner chooses to create, edit, or cancel/delete an event.
5. **Create event** — Owner enters event title, date, time, location, description, and optional image.
6. **Edit event** — Owner selects an upcoming event and modifies its details.
7. **Validate required fields** — Title, date, time, and location are mandatory; if missing, a validation error is shown.
8. **Save event** — Valid event details are saved.
9. **Publish event** — The event is published to the platform.
10. **Show confirmation** — A confirmation message is displayed after successful creation.
11. **Display in listings** — Published events appear in public event listings.
12. **Save changes** — Edited details are saved.
13. **Update confirmation** — A confirmation message is displayed after updating.
14. **Push real-time update** — Event listings are updated immediately across clients.
15. **Cancel or delete event** — Owner selects and confirms cancellation or deletion.
16. **Mark as cancelled** — The event remains visible but is clearly marked "Cancelled".
17. **Remove from listings** — The event is removed from public listings based on system design.
18. **Cancel confirmation** — A confirmation message is displayed after cancellation or deletion.
19. **Real-time sync** — Subgraph ensuring created, updated, and cancelled events are reflected immediately in public listings.
