# CloudKit Configuration for Sports Live Activities

This app uses ActivityKit with token-based push updates to keep sports Live Activities fresh. Follow the steps below to provision CloudKit schema, server-to-server updates, and push notification entitlements.

## 1. Update CloudKit Schema

Import `MiddlesexSchema.ckdb` into the development environment if you have not already done so. This schema now defines the following additional record types:

- `SportsLiveUpdate` – latest scoreboard update for each event
- `SportsReporterClaim` – enforces a single reporter per event at a time
- `SportsLiveSubscription` – maps Live Activity push tokens to events

After validating in development, deploy the schema changes to production.

## 2. Add New Record Fields

Check that the following fields exist for each record type:

### SportsLiveUpdate
- `id` (String, indexed)
- `eventId` (String, indexed)
- `sport` (String)
- `status` (String)
- `homeScore`, `awayScore` (Int)
- `periodLabel` (String)
- `clockRemaining` (Double)
- `clockLastUpdated` (Date)
- `possession` (String)
- `lastEventSummary`, `lastEventDetail` (String)
- `highlightIcon` (String)
- `topFinishersJSON`, `teamResultsJSON` (String)
- `summary` (String)
- `reporterId`, `reporterName` (String)
- `createdAt`, `updatedAt` (Date)

### SportsReporterClaim
- `id` (String, indexed)
- `eventId` (String, indexed)
- `reporterId` (String)
- `reporterName` (String)
- `claimedAt` (Date)
- `expiresAt` (Date)
- `status` (String)

### SportsLiveSubscription
- `id` (String, indexed)
- `eventId` (String, indexed)
- `userId` (String)
- `sport` (String)
- `pushToken` (String)
- `deviceName` (String)
- `createdAt` (Date)

Grant read access to `_world` for updates and subscriptions so the device can pull them down.

## 3. Configure Push-to-Activity Updates

1. Enable **Push Notifications** capability in your Xcode project for the app target and the widget extension.
2. Under **Background Modes**, enable `Background fetch` and `Remote notifications`.
3. In Apple Developer Center, create a **push notification key** or certificate for the app if you do not have one.
4. In CloudKit Dashboard, go to **Containers → Middlesex → Development → Notifications** and enable server-to-server notifications.
5. Configure server logic (Cloud Functions, server script, or CloudKit JS) to:
   - Update the `SportsLiveUpdate` record with the new ContentState payload.
   - Send an ActivityKit push to each registered `SportsLiveSubscription` token.

Refer to Apple’s "Pushing Live Activity Updates" documentation for the JSON payload format. A minimal payload looks like this:

```json
{
  "aps": {
    "timestamp": 1736203200,
    "event": "update"
  },
  "content-state": {
    "status": "live",
    "homeScore": 21,
    "awayScore": 14,
    "periodLabel": "Q3 08:12",
    "lastEventSummary": "Touchdown – Middlesex",
    "highlightIcon": "figure.american.football"
  },
  "dismissal-date": 1736206800
}
```

## 4. Reporter Workflow

- Reporters claim an event via the `SportsReporterClaim` record. Claims expire automatically after the configured duration.
- Only one reporter can hold an active claim at a time. The reporter’s name appears on the Live Activity UI for transparency.

## 5. Dev Testing Checklist

- Ensure the device runs iOS 17.2 or later (Live Activity push updates require iOS 17.2+).
- Start a Live Activity from the Sports view and verify the state persists after force-quitting the app.
- Simulate server pushes using the `apns-push-type: activity` header and the Xcode "Send Live Activity Update" debug tool.
- Confirm soccer, football, and cross country layouts render with sport-specific colors and data.

Keep this file updated if the schema evolves.
