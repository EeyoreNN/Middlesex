# CloudKit Schema Setup

## Current Schema File
`MiddlesexSchema.ckdb` contains all record types for the app.

## Recent Record Types Added
- **AppSettings** - For storing OpenAI API key and other app-wide settings
- **CustomClass** - For user-submitted custom class requests
- **SpecialSchedule** - For admin-created special day schedules

## How to Upload Schema to CloudKit

### Step 1: Access CloudKit Dashboard
1. Go to: https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select your app container: `iCloud.com.nicholasnoon.Middlesex`

### Step 2: Import Schema
1. Click on **Schema** in the left sidebar
2. Make sure you're in **Development** environment
3. Click **Import Schema** button (top right)
4. Select the file: `MiddlesexSchema.ckdb`
5. Review the changes
6. Click **Import**

### Step 3: Verify Import
After importing, verify these record types exist:
- ✅ MenuItem
- ✅ ClassSchedule
- ✅ Announcement
- ✅ SportsEvent
- ✅ SportsTeam
- ✅ AdminCode
- ✅ SpecialSchedule
- ✅ **AppSettings** (NEW)
- ✅ **CustomClass** (NEW)

### Step 4: Test in Development
1. Run the app in simulator/device
2. Try saving the OpenAI API key (Admin Dashboard → API Configuration)
3. Check console logs for success
4. Try submitting a custom class request

### Step 5: Deploy to Production (When Ready)
1. Go to Schema → Development
2. Click **Deploy Schema Changes**
3. Review changes carefully
4. Click **Deploy to Production**

⚠️ **Warning**: Production schema changes are permanent and affect all users!

## Current Schema Status
- Development: ⚠️ **Needs Update** (AppSettings and CustomClass missing)
- Production: ⚠️ **Needs Update** (AppSettings and CustomClass missing)

## What Happens If Schema Is Not Uploaded?
- OpenAI API key cannot be saved to CloudKit (will only save locally)
- Custom class submissions will fail
- Users will see errors when trying to use these features
- API key test will fail with "Unknown Item" error

## Quick Fix for Testing Without CloudKit
The app has fallback mechanisms:
- API key can be stored in UserDefaults (local only)
- API key can be set in Info.plist
- Custom classes can be submitted but won't be saved

However, for production use, **you must upload the schema to CloudKit**.
