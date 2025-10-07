# Middlesex School App - CloudKit Schema

This document outlines the CloudKit database schema for the Middlesex School App.

## Database: Public Database
All data should be stored in the public CloudKit database to allow read access for all users.

---

## Record Types

### 1. MenuItem
Stores daily menu items for breakfast, lunch, and dinner.

**Record Type Name:** `MenuItem`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `date` | Date/Time | Yes | Date this menu is for |
| `mealType` | String | Yes | "breakfast", "lunch", or "dinner" |
| `title` | String | No | Name of the dish/item |
| `description` | String | No | Detailed description of the item |
| `category` | String | Yes | "main", "side", "dessert", "beverage" |
| `allergens` | String | No | Comma-separated list of allergens |
| `isVegetarian` | Int64 | No | 1 if vegetarian, 0 if not |
| `isVegan` | Int64 | No | 1 if vegan, 0 if not |
| `createdAt` | Date/Time | No | When record was created |
| `updatedAt` | Date/Time | No | Last update timestamp |

**Indexes:**
- `date` (Queryable, Sortable)
- `mealType` (Queryable)

---

### 2. ClassSchedule
Stores class schedule information for students.

**Record Type Name:** `ClassSchedule`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `dayOfWeek` | String | Yes | "Monday", "Tuesday", etc. |
| `period` | Int64 | Yes | Period number (1-8) |
| `className` | String | Yes | Name of the class |
| `teacher` | String | No | Teacher name |
| `room` | String | No | Room number/location |
| `startTime` | String | No | Start time (e.g., "8:00 AM") |
| `endTime` | String | No | End time (e.g., "8:50 AM") |
| `color` | String | No | Hex color for UI display |
| `isActive` | Int64 | Yes | 1 if currently active schedule |
| `semester` | String | Yes | "Fall" or "Spring" |
| `year` | Int64 | Yes | School year (e.g., 2025) |
| `createdAt` | Date/Time | No | When record was created |

**Indexes:**
- `dayOfWeek` (Queryable)
- `period` (Queryable, Sortable)
- `isActive` (Queryable)

---

### 3. Announcement
Stores school announcements and news.

**Record Type Name:** `Announcement`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `title` | String | Yes | Announcement title |
| `body` | String | No | Full announcement text |
| `publishDate` | Date/Time | Yes | When to publish/display |
| `expiryDate` | Date/Time | Yes | When to stop displaying |
| `priority` | String | Yes | "high", "medium", "low" |
| `category` | String | Yes | "academic", "sports", "events", "general" |
| `author` | String | No | Who posted the announcement |
| `imageURL` | String | No | Optional image URL |
| `isActive` | Int64 | Yes | 1 if should be displayed |
| `isPinned` | Int64 | Yes | 1 if pinned to top |
| `isCritical` | Int64 | Yes | 1 if critical alert notification |
| `createdAt` | Date/Time | No | When record was created |
| `updatedAt` | Date/Time | No | Last update timestamp |

**Indexes:**
- `publishDate` (Queryable, Sortable)
- `priority` (Queryable)
- `category` (Queryable)
- `isActive` (Queryable)
- `isPinned` (Queryable)
- `isCritical` (Queryable)

**Security Roles:**
- Authenticated Users: Read ✅, Create ✅, Write ✅

---

### 4. SportsEvent
Stores sports games, matches, and events.

**Record Type Name:** `SportsEvent`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `sport` | String | Yes | "Football", "Soccer", "Basketball", etc. |
| `eventType` | String | Yes | "game", "practice", "tournament" |
| `opponent` | String | No | Opposing team name |
| `eventDate` | Date/Time | Yes | Date and time of event |
| `location` | String | No | Location/venue |
| `isHome` | Int64 | No | 1 if home game, 0 if away |
| `middlesexScore` | Int64 | No | Middlesex team score (-1 if not played) |
| `opponentScore` | Int64 | No | Opponent score (-1 if not played) |
| `status` | String | Yes | "scheduled", "in_progress", "completed", "cancelled" |
| `season` | String | Yes | "Fall", "Winter", "Spring" |
| `year` | Int64 | Yes | Year (e.g., 2025) |
| `notes` | String | No | Additional details |
| `createdAt` | Date/Time | No | When record was created |
| `updatedAt` | Date/Time | No | Last update timestamp |

**Indexes:**
- `sport` (Queryable)
- `eventDate` (Queryable, Sortable)
- `status` (Queryable)
- `season` (Queryable)

---

### 5. SportsTeam
Stores information about sports teams.

**Record Type Name:** `SportsTeam`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `sport` | String | Yes | "Football", "Soccer", "Basketball", etc. |
| `teamName` | String | No | Full team name |
| `season` | String | Yes | "Fall", "Winter", "Spring" |
| `year` | Int64 | Yes | Year (e.g., 2025) |
| `wins` | Int64 | No | Number of wins |
| `losses` | Int64 | No | Number of losses |
| `ties` | Int64 | No | Number of ties |
| `coachName` | String | No | Head coach name |
| `captains` | String | No | Comma-separated captain names |
| `rosterURL` | String | No | Link to full roster |
| `isActive` | Int64 | Yes | 1 if currently active |
| `createdAt` | Date/Time | No | When record was created |
| `updatedAt` | Date/Time | No | Last update timestamp |

**Indexes:**
- `sport` (Queryable)
- `season` (Queryable)
- `isActive` (Queryable)

---

### 6. AdminCode
Stores temporary admin access codes generated by super admins.

**Record Type Name:** `AdminCode`

| Field Name | Type | Indexed | Description |
|------------|------|---------|-------------|
| `id` | String | Yes | Unique identifier (UUID) |
| `code` | String | Yes | 8-digit numeric code |
| `generatedBy` | String | No | Who generated the code |
| `generatedAt` | Date/Time | Yes | When code was created |
| `expiresAt` | Date/Time | Yes | When code expires (2 hours) |
| `isUsed` | Int64 | Yes | 1 if code has been claimed |
| `usedBy` | String | No | Who claimed the code |
| `usedAt` | Date/Time | No | When code was claimed |

**Indexes:**
- `code` (Queryable)
- `generatedAt` (Queryable, Sortable)
- `expiresAt` (Queryable, Sortable)
- `isUsed` (Queryable)

**Security Roles:**
- Authenticated Users: Read ✅, Create ✅, Write (Creator Only) ✅

---

## Security Roles

### Public Database Permissions

**IMPORTANT:** For each record type, you must configure Security Roles in CloudKit Dashboard:

1. Go to CloudKit Dashboard → Schema → Record Types
2. Select each record type
3. Click "Security Roles"
4. For **Authenticated Users** role:
   - **MenuItem, ClassSchedule, SportsEvent, SportsTeam**: Read ✅ only
   - **Announcement**: Read ✅, Create ✅, Write ✅
   - **AdminCode**: Read ✅, Create ✅, Write (Creator) ✅

### Private Database Permissions
Not used for this app - all data is public

---

## Query Examples

### Get Today's Lunch Menu
```
Record Type: MenuItem
Predicate: date == TODAY AND mealType == "lunch"
Sort: category ASC
```

### Get Active Announcements
```
Record Type: Announcement
Predicate: isActive == 1 AND publishDate <= NOW AND expiryDate >= NOW
Sort: isPinned DESC, publishDate DESC
```

### Get Upcoming Sports Events
```
Record Type: SportsEvent
Predicate: eventDate >= NOW AND status != "cancelled"
Sort: eventDate ASC
Limit: 10
```

### Get Monday's Class Schedule
```
Record Type: ClassSchedule
Predicate: dayOfWeek == "Monday" AND isActive == 1
Sort: period ASC
```

---

## Setup Instructions

1. **Create CloudKit Container:**
   - Go to Apple Developer Portal
   - Create CloudKit container: `iCloud.com.yourteam.Middlesex`

2. **Configure Record Types:**
   - Navigate to CloudKit Dashboard
   - Select your container
   - Create each record type with the fields listed above

3. **Set Indexes:**
   - For each record type, add the specified indexes
   - Enable queryable and sortable as noted

4. **Configure Permissions:**
   - Set World read permissions for all record types
   - Restrict write access to admin role

5. **Deploy Schema:**
   - Deploy schema to Production environment
   - Test with sample data in Development environment first

---

## Notes

- All dates should be stored in UTC
- Use consistent string values (e.g., "Monday" not "monday")
- Store colors as hex strings (e.g., "#FF0000")
- Use -1 for scores of games not yet played
- Delete old records periodically (menus > 30 days, past events, expired announcements)
