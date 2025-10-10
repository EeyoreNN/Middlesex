# Push Notification Setup Guide

This guide explains how to complete the Apple Push Notification service (APNs) setup for the Middlesex app.

## Current Status

✅ **Completed:**
- Notification permission requests
- UNUserNotificationCenter delegate setup
- Local notification scheduling
- Notification categories (NEXT_CLASS, SPORTS_GAME, ANNOUNCEMENT)
- Device token registration code (AppDelegate)
- CloudKit DeviceToken storage
- Test notification functionality

⏳ **Remaining:**
- APNs capability enablement in Xcode
- APNs Auth Key or Certificate generation
- Server-side push notification infrastructure
- CloudKit schema deployment

---

## Part 1: Xcode Project Configuration

### Step 1: Enable Push Notifications Capability

1. Open `Middlesex.xcodeproj` in Xcode
2. Select the **Middlesex** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**

### Step 2: Enable Background Modes

1. Still in **Signing & Capabilities**
2. Click **+ Capability** again
3. Add **Background Modes**
4. Check the following boxes:
   - ☑️ **Remote notifications**

### Step 3: Verify iCloud Capability

Ensure the following is already configured (should be from CloudKit setup):
- ☑️ **iCloud** capability enabled
- ☑️ **CloudKit** service checked
- ☑️ Container: `iCloud.com.nicholasnoon.Middlesex`

---

## Part 2: Apple Developer Portal Configuration

### Option A: APNs Auth Key (Recommended - Easier)

**Benefits:**
- One key works for all apps
- Never expires
- Works across Development and Production
- Easier to manage

**Steps:**

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Keys** in the sidebar
4. Click **+** to create a new key
5. Enter a name: `Middlesex APNs Key`
6. Check **Apple Push Notifications service (APNs)**
7. Click **Continue**, then **Register**
8. **IMPORTANT:** Download the `.p8` file - you can only download this once!
9. Note the **Key ID** (10-character string)
10. Note your **Team ID** (found in Membership section)

**Save these securely:**
- `.p8` file (the private key)
- Key ID (e.g., `ABC1234DEF`)
- Team ID (e.g., `XYZ5678GHI`)

### Option B: APNs Certificate (Legacy)

**Drawbacks:**
- Requires separate certificates for Development and Production
- Expires after 1 year
- More complex to manage

**Steps:**

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers**, select your app ID: `com.nicholasnoon.Middlesex`
4. Ensure **Push Notifications** is checked under Capabilities
5. Click **Configure** next to Push Notifications
6. Create certificates for Development and Production:
   - Generate a Certificate Signing Request (CSR) from Keychain Access on Mac
   - Upload CSR to create certificate
   - Download `.cer` file
   - Double-click to install in Keychain
   - Export as `.p12` with a password

---

## Part 3: CloudKit Schema Deployment

The CloudKit schema has been updated with the `DeviceToken` record type, but it needs to be deployed to iCloud.

### Deploy Schema to Development Environment

1. Open CloudKit Dashboard: [https://icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard)
2. Select container: `iCloud.com.nicholasnoon.Middlesex`
3. Select **Development** environment
4. Go to **Schema** → **Record Types**
5. Create the **DeviceToken** record type if not exists:
   - Field: `userId` (String, Queryable)
   - Field: `deviceToken` (String, Queryable)
   - Field: `createdAt` (Date/Time, Queryable, Sortable)
   - Field: `lastUpdated` (Date/Time, Queryable, Sortable)
   - Field: `isActive` (Int(64), Queryable)
6. Set permissions:
   - Read: Creator
   - Create: Creator
   - Write: Creator

### Deploy to Production (When Ready)

⚠️ **Only do this after testing in Development!**

1. In CloudKit Dashboard, go to **Deploy Schema Changes**
2. Review changes (should show DeviceToken record type addition)
3. Deploy to Production environment

---

## Part 4: Testing Push Notifications

### Test Local Notifications (No Server Required)

1. Build and run the app on a **physical iOS device** (simulator doesn't support APNs)
2. Sign in with Apple ID
3. Grant notification permissions when prompted
4. Go to **Home** → **Notification Settings**
5. Tap **Send Test Notification**
6. Background the app (go to home screen)
7. Wait 5 seconds
8. You should see: "Test Notification - If you see this, notifications are working!"

**If this works:** Local notifications are functional ✅

### Test APNs Device Token Registration

1. Run the app on a **physical device**
2. Check Xcode console for one of these messages:
   - ✅ `APNs device token: [64-character hex string]` - Success!
   - ❌ `Failed to register for remote notifications: [error]` - See troubleshooting below

**Common errors:**
- "no valid 'aps-environment' entitlement" → Add Push Notifications capability (Part 1, Step 1)
- "not supported in simulator" → Must use physical device
- Network error → Check internet connection

### Verify Device Token Storage in CloudKit

1. Open CloudKit Dashboard
2. Select **Development** environment
3. Go to **Data** → **Records**
4. Select record type: **DeviceToken**
5. You should see a record with:
   - `userId`: Your Apple ID
   - `deviceToken`: 64-character hex string
   - `createdAt`: Recent timestamp
   - `isActive`: 1

**If this works:** Device token registration is functional ✅

---

## Part 5: Server-Side Push Infrastructure

To send push notifications from a server, you need to build a backend service.

### Server Requirements

- Backend server (Node.js, Python, Go, etc.)
- APNs HTTP/2 API integration
- CloudKit query capability to fetch device tokens

### Recommended Approach: Node.js with `apn` Package

**Install dependencies:**
```bash
npm install apn
```

**Example server code (Node.js):**

```javascript
const apn = require('apn');

// Configure APNs provider with Auth Key (recommended)
const apnProvider = new apn.Provider({
  token: {
    key: './AuthKey_ABC1234DEF.p8', // Path to .p8 file
    keyId: 'ABC1234DEF',              // Your Key ID
    teamId: 'XYZ5678GHI'              // Your Team ID
  },
  production: false // Use true for production
});

// Alternatively, configure with Certificate (legacy)
// const apnProvider = new apn.Provider({
//   cert: './cert.pem',
//   key: './key.pem',
//   production: false
// });

// Send notification
async function sendNotification(deviceToken, title, body, category) {
  const notification = new apn.Notification();

  notification.alert = {
    title: title,
    body: body
  };
  notification.topic = 'com.nicholasnoon.Middlesex'; // Your bundle ID
  notification.category = category; // NEXT_CLASS, SPORTS_GAME, ANNOUNCEMENT
  notification.sound = 'default';
  notification.badge = 1;

  const result = await apnProvider.send(notification, deviceToken);

  if (result.failed.length > 0) {
    console.error('Failed to send notification:', result.failed[0].response);
  } else {
    console.log('✅ Notification sent successfully');
  }
}

// Example: Send announcement notification
sendNotification(
  'a1b2c3d4e5f6...', // Device token from CloudKit
  'New Announcement: Assembly Tomorrow',
  'There will be an all-school assembly at 10am in the chapel.',
  'ANNOUNCEMENT'
);
```

### CloudKit Integration

To fetch device tokens for users who should receive notifications:

```javascript
// Pseudocode - Use CloudKit JS or server-to-server API
async function getDeviceTokensForUser(userId) {
  const query = {
    recordType: 'DeviceToken',
    filterBy: [
      { fieldName: 'userId', comparator: 'EQUALS', fieldValue: userId },
      { fieldName: 'isActive', comparator: 'EQUALS', fieldValue: 1 }
    ]
  };

  const results = await cloudKit.query(query);
  return results.records.map(r => r.fields.deviceToken.value);
}
```

### When to Send Notifications

The server should send push notifications when:

1. **New Announcement** (category: `ANNOUNCEMENT`)
   - Trigger: Admin creates announcement in CloudKit
   - Fetch: All active device tokens for users with `notificationsAnnouncements = true`
   - Send immediately

2. **Sports Game Update** (category: `SPORTS_GAME`)
   - Trigger: Score update in SportsLiveUpdate record
   - Fetch: Device tokens for users following that sport
   - Check: User has `notificationsSportsUpdates = true`
   - Send immediately

3. **Next Class Reminder** (category: `NEXT_CLASS`)
   - Trigger: Current class ending (scheduled)
   - Fetch: User's device tokens
   - Check: User has `notificationsNextClass = true`
   - Send: When current class ends, notify about next class

**Note:** For next class reminders, consider using local notifications (already implemented) instead of push, since the schedule is predictable.

---

## Part 6: Notification Handling in App

The app is already set up to handle notifications:

### Foreground Presentation
When app is open and notification arrives:
- Implemented in: `NotificationManager.swift:78-85`
- Shows banner, plays sound, updates badge

### Tap Handling
When user taps notification:
- Implemented in: `NotificationManager.swift:88-110`
- Routes to appropriate view based on category:
  - `NEXT_CLASS` → Schedule view (TODO)
  - `SPORTS_GAME` → Sports view (TODO)
  - `ANNOUNCEMENT` → Announcements view (TODO)

**Next steps for navigation:**
Implement deep linking to navigate to the correct view when notification is tapped.

---

## Troubleshooting

### Problem: "Failed to register for remote notifications"

**Cause:** Missing Push Notifications capability
**Solution:** Follow Part 1, Step 1 to add capability

### Problem: "no valid 'aps-environment' entitlement"

**Cause:** Entitlements not properly configured
**Solution:**
1. Clean build folder (Cmd+Shift+K)
2. Delete app from device
3. Rebuild and reinstall

### Problem: Device token not appearing in CloudKit

**Cause:** User not signed in or CloudKit permission denied
**Solution:**
1. Ensure user completed Sign in with Apple
2. Check `userIdentifier` is not empty
3. Verify CloudKit schema deployed

### Problem: Notifications not appearing

**Possible causes:**
1. Notifications disabled in Settings → check `Settings > Notifications > Middlesex`
2. Do Not Disturb enabled → check Focus settings
3. App in foreground → notifications should show as banner (already configured)
4. Invalid device token → check console for registration errors

### Problem: Push notifications not received from server

**Checklist:**
1. APNs Auth Key or Certificate correctly configured on server
2. Using correct bundle ID: `com.nicholasnoon.Middlesex`
3. Using correct environment (development vs production)
4. Device token is valid and active
5. Server can reach APNs (port 443 outbound)

---

## Security Best Practices

1. **Never commit** `.p8` auth key or `.p12` certificate to version control
2. **Store credentials** in environment variables or secure vault
3. **Validate** device tokens before sending (check isActive flag)
4. **Rate limit** notifications to avoid spam
5. **Clean up** inactive tokens periodically (remove tokens for uninstalled apps)
6. **Use** separate auth keys for development and production (optional but recommended)

---

## Next Steps

1. ✅ Complete Xcode configuration (Part 1)
2. ✅ Generate APNs Auth Key (Part 2)
3. ✅ Deploy CloudKit schema (Part 3)
4. ✅ Test device token registration (Part 4)
5. 🔄 Build server-side push service (Part 5)
6. 🔄 Implement deep linking for notification taps (Part 6)
7. 🔄 Test end-to-end push delivery
8. 🔄 Deploy to production

---

## Additional Resources

- [Apple Push Notification Service Overview](https://developer.apple.com/documentation/usernotifications)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Node.js APNs Package](https://github.com/node-apn/node-apn)
- [Testing Push Notifications](https://developer.apple.com/documentation/usernotifications/testing_notifications_using_the_push_notification_console)
