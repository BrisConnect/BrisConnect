# Missing User Stories

These user stories represent features implemented in the BrisConnect mobile app that are not documented in the original Admin.docx specification.

---

## **Shared Features**

**27. As a User, I want to see a welcome screen so that I can choose to log in or create an account.**

Acceptance Criteria
- The system displays a branded welcome screen with the app logo on first launch.
- The welcome screen shows a "Log In" button and a "Create Account" button.
- Tapping "Log In" navigates to the Login Role Selection screen.
- Tapping "Create Account" navigates to the Register Role Selection screen.
- The screen displays branding elements consistent with the app theme.

**28. As a User, I want to select my role before logging in so that I am directed to the correct login screen.**

Acceptance Criteria
- The system displays three login options: Visitor, Local, and Admin.
- Each option shows a descriptive subtitle explaining the role.
- Tapping an option navigates to the corresponding role-specific login screen.
- The layout is responsive and centred on different screen sizes.

**29. As a User, I want to select my role before registering so that I create the correct type of account.**

Acceptance Criteria
- The system displays two registration options: Visitor and Local.
- Admin registration is not available through the registration screen.
- Each option shows a descriptive subtitle explaining the role.
- Tapping an option navigates to the corresponding role-specific registration screen.

**30. As a User, I want to select my interest categories so that I can receive personalised event recommendations.**

Acceptance Criteria
- The system displays eight interest categories: Cultural, Music and Entertainment, Sports, Food and Dining, Nature and Outdoors, Historical and Attractions, Markets and Shopping, and Workshops and Community.
- The user can select multiple categories.
- Selected categories are saved and persisted across sessions.
- The feature works for both Local and Visitor users.
- A confirmation message is shown when categories are saved successfully.

**31. As a User, I want to configure location settings so that nearby recommendations match my preferred search radius.**

Acceptance Criteria
- The system provides a toggle to enable or disable current location usage.
- The system provides radius options of 5, 10, 20, 50, and 100 kilometres.
- Settings are persisted across sessions for the logged-in user.
- The feature works for both Local and Visitor users.
- A message is shown if the user is not logged in.

**32. As a User, I want to customise the app theme and text size so that the interface matches my visual preferences.**

Acceptance Criteria
- The system provides theme options: System, Light, and Dark.
- The system provides a text scale slider ranging from 0.9 to 1.3.
- Theme changes are applied immediately across the app.
- Settings are persisted across sessions.
- The feature works for both Local and Visitor users.

**33. As a User, I want to browse Brisbane Stories so that I can discover cultural and historical narratives about Brisbane.**

Acceptance Criteria
- The system displays approved Brisbane Stories from the content collection.
- Stories are organised into five categories: First Nations, Arts, Landmarks, Food, and Festivals.
- Each story shows a title, description, image, and category badge.
- The user can filter stories by category.
- Audio guide narration is available for each story.
- The user can share story content.
- Stories are sorted by publication date with newest first.

**34. As a User, I want to view food place details so that I can discover dining options in Brisbane.**

Acceptance Criteria
- The system displays food place details including title, description, location, and cuisine type.
- The detail screen shows ratings, price, and category information when available.
- The user can open the food place location in Google Maps.
- The user can share food place details.
- An audio narration is generated or provided for the food place.
- A placeholder image is shown when no image is available.

**35. As a User, I want to view stadium and venue details so that I can learn about event venues before visiting.**

Acceptance Criteria
- The system displays venue details including title, description, and location.
- The detail screen shows event dates, pricing, and category information when available.
- The location defaults to a placeholder label when not provided.
- Missing optional fields do not break the page layout.

**36. As a User, I want to submit app feedback so that I can report bugs or suggest improvements.**

Acceptance Criteria
- The system provides a feedback form with subject and details fields.
- The form includes a category selection with options: Bug, Misleading Info, Usability, Performance, and Other.
- The form includes a severity selection with options: Low, Medium, High, and Critical.
- The subject field requires a minimum of five characters.
- Submitted feedback is stored with a pending triage status and a timestamp.
- The reporter's name, email, and role are captured automatically.

---

## **Admin**

**37. As an Admin, I want to manage all user accounts so that I can oversee platform membership across all roles.**

Acceptance Criteria
- The system displays a unified list of all users across Visitor, Local, and Admin roles.
- The Admin can search users by email or name.
- The Admin can filter users by role: All, Visitor, Local, or Admin.
- The Admin can filter users by status: All, Active, Inactive, Pending, Approved, or Rejected.
- The Admin can deactivate a user account after confirmation.
- The Admin can reactivate a previously deactivated account.
- The Admin can approve or reject Local user accounts from this screen.
- Email and SMS notifications are sent on approval or rejection actions.

**38. As an Admin, I want to review reported events so that I can take action on user complaints about inappropriate content.**

Acceptance Criteria
- The system displays reported events in a dedicated review screen.
- Reports can be filtered by status: Pending, Reviewing, Resolved, or Dismissed.
- Each report shows the reporter details, reason, and associated event information.
- The Admin can update the status of a report.
- An empty state message is shown when no reports match the selected status.
- This screen is separate from the event moderation workflow.

**39. As an Admin, I want to review app feedback submissions so that I can track and resolve user-reported issues.**

Acceptance Criteria
- The system displays submitted feedback items with dual filtering by status and severity.
- Status filter options include: Pending Triage, In Progress, Resolved, and Will Not Fix.
- Severity filter options include: All, Critical, High, Medium, and Low.
- The Admin can update the status of a feedback item.
- Feedback items are sorted by newest first.
- A resolution due date is calculated automatically on submission.

**40. As an Admin, I want to send SMS broadcasts so that I can communicate important announcements to platform users.**

Acceptance Criteria
- The system provides a compose form with a message field and audience selection.
- Audience options include: Locals and Visitors, Locals Only, and Visitors Only.
- The Admin can restrict the broadcast to approved Local users only.
- The system queues SMS messages and reports the number of recipients.
- A confirmation message shows the number of recipients or indicates if no recipients were found.
- The message field is required and validated before sending.

**41. As an Admin, I want to edit event details directly so that I can correct event information beyond approving or rejecting.**

Acceptance Criteria
- The system provides an edit form pre-filled with the existing event data.
- The Admin can update the title, location, description, date, and category.
- The category selection includes: Culture, Music, Food, Sports, Community, Education, Family, and General.
- The Admin can replace or remove the event image.
- Updated event information is saved to the system.
- The date picker supports date selection within a range of one year in the past to three years in the future.

---

## **Local**

**42. As a Local user, I want to register for an account so that I can apply for publishing access on the platform.**

Acceptance Criteria
- The system provides a registration form with fields for business name, email, password, phone number, and suburb.
- Phone numbers are converted to Australian E.164 format.
- Email validation is enforced.
- Successful registration redirects to the Local login screen with email pre-filled.
- An error message is shown if registration fails.
- The form indicates that registration is for a Local account without admin access.
- The submit button is disabled while the form is being processed.

---

## **Visitor**

**43. As a Visitor, I want to register for an account so that I can access discovery and planning features.**

Acceptance Criteria
- The system provides a registration form with fields for name, email, password, and phone number.
- Phone numbers are converted to Australian E.164 format.
- Email validation is enforced.
- Successful registration redirects to the Visitor login screen with email pre-filled.
- An error message is shown if registration fails.
- The submit button is disabled while the form is being processed.

**44. As a Visitor, I want to view a list of my interested events so that I can review all the events I have saved.**

Acceptance Criteria
- The system displays a list of events the Visitor has marked as interested.
- Only approved events are shown in the list.
- The Visitor can remove an event from the interested list.
- A confirmation message is shown when an event is removed.
- An empty state message is shown when no events are saved.
- A loading indicator is displayed while events are being fetched.
