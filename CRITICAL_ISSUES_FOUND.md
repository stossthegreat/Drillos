# 🚨 CRITICAL ISSUES FOUND - October 5, 2025

## Summary
After thorough investigation, I found **THREE CRITICAL ISSUES** preventing the scheduling and alarm system from working:

---

## ❌ **ISSUE 1: Missing "Custom" Frequency Option**

### Problem:
The frequency dropdown in `/lib/widgets/habit_create_edit_modal.dart` (line 556) only has:
```dart
options: ['daily', 'weekdays', 'everyN']
```

But the code in `/lib/screens/new_habits_screen.dart` tries to handle `'custom'` schedules (lines 170, 229).

### Impact:
- Users **CANNOT** set custom date ranges for habits
- The "custom" schedule type is completely inaccessible

### Fix Required:
Update line 556 in `habit_create_edit_modal.dart`:
```dart
options: ['daily', 'weekdays', 'everyN', 'custom']
```

Then add UI for custom date picking when `frequency == 'custom'`.

---

## ❌ **ISSUE 2: Tasks Have NO Frequency Selector**

### Problem:
Line 549 in `/lib/widgets/habit_create_edit_modal.dart`:
```dart
if (_formData['type'] != 'task') ...[
  // Frequency selector only for habits
]
```

Tasks are EXCLUDED from having frequency options!

### Impact:
- **Tasks default to 'daily' schedule** (line 163 in `new_habits_screen.dart`)
- Users cannot schedule tasks for weekdays, everyN, or custom dates
- Tasks always appear every day

### Fix Required:
Remove the `if (_formData['type'] != 'task')` condition so tasks can also have scheduling options.

---

## ❌ **ISSUE 3: Alarms Not Firing (Worker Not Running)**

### Problem:
The scheduler worker in `src/workers/scheduler.worker.ts` **instantiates immediately** when imported, but:

1. **Railway Main Service**: Runs `node dist/server.js`
   - Imports `bootstrapSchedulers()` from `src/jobs/scheduler.ts`
   - This function **ONLY registers jobs**, does NOT process them
   - **NO Worker running** = jobs never execute

2. **Railway Scheduler Service** (if separate): Runs `node dist/workers/scheduler.worker.js`
   - Would need to be a separate deployment
   - Dockerfile builds successfully
   - But user didn't deploy it separately

### Impact:
- **Alarms NEVER fire**
- **Daily briefs NEVER run**
- **Nudges NEVER trigger**
- Jobs are registered in BullMQ but no worker is listening

### Fix Required:
**Option A: Single Service (Recommended)**
Import and run the worker in `server.ts`:
```typescript
// Add this import
import './workers/scheduler.worker'; // This instantiates the Worker

// server.ts line 228
setImmediate(() => bootstrapSchedulers().catch(console.error));
```

**Option B: Separate Worker Service on Railway**
Deploy a second Railway service:
- **Root Directory**: `backend`
- **Start Command**: `node dist/workers/scheduler.worker.js`
- **Same ENV vars** as main service

---

## 📊 **Current State vs Expected**

| Feature | Expected | Actual | Status |
|---------|----------|--------|--------|
| Habit scheduling (daily) | ✅ Works | ✅ Works | ✅ OK |
| Habit scheduling (weekdays) | ✅ Works | ✅ Works | ✅ OK |
| Habit scheduling (everyN) | ✅ Works | ✅ Works | ✅ OK |
| Habit scheduling (custom) | ✅ Works | ❌ Not in UI | ❌ BROKEN |
| Task scheduling | ✅ Works | ❌ No UI | ❌ BROKEN |
| Alarms firing | ✅ Works | ❌ No worker | ❌ BROKEN |
| Daily briefs | ✅ Works | ❌ No worker | ❌ BROKEN |
| Nudges | ✅ Works | ❌ No worker | ❌ BROKEN |

---

## 🛠️ **IMMEDIATE ACTION PLAN**

### Priority 1: Fix Alarms (CRITICAL)
1. Add `import './workers/scheduler.worker';` to `server.ts`
2. Redeploy to Railway
3. Check logs for: `🔧 Scheduler worker initialized and listening for jobs...`

### Priority 2: Fix Task Scheduling
1. Remove `if (_formData['type'] != 'task')` condition from modal
2. Test creating tasks with different schedules

### Priority 3: Add Custom Frequency
1. Add `'custom'` to frequency options
2. Add UI for custom date range picker
3. Test habit with custom date range

---

## 🔍 **Verification Steps**

After fixes:
1. **Create a habit** with reminder → Check if alarm fires
2. **Create a task** with weekdays schedule → Check if it only appears on weekdays
3. **Wait for daily brief** (7 AM user timezone) → Check if notification arrives
4. **Check Railway logs** → Should see "⏰ Scan alarms processed: X"

---

## 📝 **Files Modified in This Session**

- ✅ `backend/src/jobs/scheduler.ts` - Removed duplicate Worker
- ✅ `backend/src/workers/scheduler.worker.ts` - Added ensure-random-nudges handler
- ✅ `backend/src/services/nudges.service.ts` - Fixed return type (Array → Object)
- ✅ `lib/screens/new_home_screen.dart` - Added `mounted` checks
- ✅ `backend/dist/*` - Built successfully
- ✅ Pushed to GitHub

---

## 🎯 **Root Cause**

**The user was right to be frustrated!** Three separate issues:
1. UI incomplete (missing custom, tasks can't schedule)
2. Worker not running (alarms/briefs/nudges never fire)
3. Complexity made it hard to diagnose

---

## 🚀 **Next Session Priority**

Fix the Worker import in `server.ts` - this is the MOST CRITICAL issue affecting alarms/briefs/nudges.

