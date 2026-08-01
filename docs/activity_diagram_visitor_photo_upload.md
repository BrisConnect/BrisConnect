# Activity Diagram: Visitor — Upload Photos

## User Story

**As a** Visitor,  
**I want to** upload photos from restaurants or local food businesses,  
**So that** I can share my experiences with the community.

## Acceptance Criteria

- User can upload one or more photos.
- Photos are associated with a selected event.
- Images are displayed in the event gallery.
- Unsupported file formats are rejected.
- Uploaded photos are visible to other users.
- Images upload within 5 seconds for files under a defined size (e.g. 10–50MB).
- Only authenticated users can upload images.
- Allowed formats: JPG, PNG, WebP only.
- Clear error messages for invalid file types or failed uploads.
- Image upload and gallery available 24/7 with 99.9% uptime.
- System supports large-scale image storage without performance degradation.

## Activity Diagram

```mermaid
flowchart TB
    Start([Visitor opens event page]) --> Authenticate{Authenticated user?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| ViewEvent[View selected event]
    ViewEvent --> OpenGallery[Open event photo gallery]
    OpenGallery --> TapUpload[Tap upload photos]

    TapUpload --> SelectPhotos[Select one or more photos]
    SelectPhotos --> ValidateFormat{File format allowed?<br/>JPG, PNG, WebP}

    ValidateFormat -->|No| RejectFormat[Reject upload with error message]
    RejectFormat --> ShowFormatError[Show: "Only JPG, PNG, and WebP are supported"]
    ShowFormatError --> EndUploadError([End])

    ValidateFormat -->|Yes| ValidateSize{File size within limit?}
    ValidateSize -->|No| RejectSize[Reject upload with error message]
    RejectSize --> ShowSizeError[Show: "File exceeds maximum size"]
    ShowSizeError --> EndUploadError

    ValidateSize -->|Yes| StartUploadTimer[Start 5-second upload timer]
    StartUploadTimer --> UploadToStorage[Upload image to scalable storage]

    UploadToStorage --> OptimiseImage[Optimise / resize image if needed]
    OptimiseImage --> SaveMetadata[Save photo metadata linked to event ID]

    SaveMetadata --> ModerationQueue[Optional moderation scan]
    ModerationQueue --> ApproveForGallery[Approve for event gallery]

    ApproveForGallery --> DisplayInGallery[Display image in event gallery]
    DisplayInGallery --> VisibleToOthers[Photo visible to other users]
    VisibleToOthers --> EndUploadSuccess([End])

    UploadToStorage --> UploadTimeout{Upload complete within 5 seconds?}
    UploadTimeout -->|No| RetryUpload[Retry upload or show timeout error]
    RetryUpload --> UploadToStorage
    UploadTimeout -->|Yes| ContinueSuccess[Continue]

    subgraph StorageAndScalability ["Storage & Scalability"]
        ReceiveImage[Receive image] --> DistributeCDN[Distribute to CDN]
        DistributeCDN --> ScaleCheck{Storage scaling OK?}
        ScaleCheck -->|No| AutoScale[Auto-scale storage backend]
        AutoScale --> ScaleCheck
        ScaleCheck -->|Yes| ContinueStorage[Continue]
    end

    subgraph UptimeMonitoring ["Uptime Monitoring"]
        MonitorServices[Monitor upload and gallery services] --> UptimeCheck{Availability >= 99.9%?}
        UptimeCheck -->|No| Failover[Trigger failover / incident response]
        Failover --> MonitorServices
        UptimeCheck -->|Yes| ContinueMonitoring[Continue monitoring]
    end
```

## Diagram Explanation

1. **Open event page** — Visitor navigates to the event they want to contribute photos to.
2. **Authentication check** — Only authenticated users can upload images.
3. **View event** — Visitor sees the selected event details.
4. **Open gallery** — Visitor opens the event photo gallery.
5. **Tap upload** — Visitor initiates the photo upload flow.
6. **Select photos** — Visitor selects one or more photos from their device.
7. **Validate format** — The system checks that each file is JPG, PNG, or WebP; unsupported formats are rejected with a clear error.
8. **Validate size** — The system checks that each file is within the defined size limit; oversized files are rejected with a clear error.
9. **Start upload timer** — A 5-second target begins for the upload.
10. **Upload to storage** — Images are uploaded to scalable cloud storage (e.g. Firebase Storage + CDN).
11. **Optimise image** — Images are resized or compressed if needed for performance.
12. **Save metadata** — Photo metadata, including event ID and uploader ID, is saved to the database.
13. **Moderation scan** — Optional automated or manual moderation scan before gallery display.
14. **Approve for gallery** — Approved photos are added to the event gallery.
15. **Display in gallery** — Photos appear in the event gallery.
16. **Visible to others** — Uploaded photos are visible to other users.
17. **Upload timeout check** — If upload exceeds 5 seconds, retry or show timeout error.
18. **Storage and scalability** — Images are distributed via CDN and storage auto-scales as volume grows.
19. **Uptime monitoring** — Upload and gallery services are monitored to maintain 99.9% availability.
