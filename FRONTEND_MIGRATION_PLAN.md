# 🎯 FRONTEND MIGRATION PLAN - Complete Ownership

## Current State vs Target State

### ❌ CURRENT (Broken):
- Backend tries to filter habits by schedule → doesn't work
- Backend calculates streaks → unreliable
- Backend manages alarms → not working
- Calendar shows wrong dates
- Habits appear on wrong days

### ✅ TARGET (Working):
- **Frontend** filters habits by schedule
- **Frontend** calculates & displays streaks locally
- **Frontend** manages all alarms natively
- Calendar accurately reflects schedule
- Habits only appear on scheduled days

---

## 📋 PHASE 1: Schedule Filtering (HOME SCREEN)

### Files to Modify:
1. **`lib/screens/new_home_screen.dart`** (PRIMARY)
   - Replace `apiClient.getBriefToday()` with `apiClient.getTodayItems()`
   - `getTodayItems()` filters habits by schedule LOCALLY
   - No more backend dependency for "today" list

2. **`lib/screens/home_screen.dart`** (LEGACY - same fix)
   - Apply same changes as `new_home_screen.dart`

### What Changes:
```dart
// OLD (backend decides):
final briefResult = await apiClient.getBriefToday();
List<dynamic> today = briefResult['today'] ?? [];

// NEW (frontend decides):
final today = await apiClient.getTodayItems();
// Filters using lib/utils/schedule.dart → HabitSchedule.isActiveOn(date)
```

### Logic in `lib/utils/schedule.dart`:
- `isActiveOn(DateTime date)` checks:
  - **startDate**: is today >= startDate?
  - **endDate**: is today <= endDate?
  - **daysOfWeek**: is today.weekday in [1,2,3,4,5,6,7]?
- Returns `true` only if ALL conditions pass

---

## 📋 PHASE 2: Calendar UI Accuracy

### Files to Modify:
1. **`lib/screens/new_habits_screen.dart`**
   - Week completion rail (lines 662-698)
   - Currently hardcoded: `isScheduled = true`
   - **FIX**: Check `HabitSchedule.isActiveOn(date)` for each day

2. **`lib/screens/new_home_screen.dart`**
   - Week day buttons (lines 230-274)
   - Should show visual indicator if habit is scheduled that day
   - Gray out days that are NOT in the schedule

### Implementation:
```dart
// For each date in the week:
for (final date in weekDates) {
  final sched = HabitSchedule.fromJson(item['schedule']);
  final isScheduled = sched.isActiveOn(date);
  final isCompleted = await _isCompletedOn(item['id'], date);
  
  // UI: 
  // - Green border if completed
  // - White border if scheduled but not completed
  // - Faded/gray if NOT scheduled
}
```

---

## 📋 PHASE 3: Streaks (Frontend Only)

### Current State:
- `lib/logic/habit_engine.dart` EXISTS but not used everywhere
- Some screens still call backend for streaks
- `lib/screens/streaks_screen.dart` calls `apiClient.getStreakSummary()`

### Target State:
- **ALL** streak calculations in `SharedPreferences`
- No backend calls for streak data
- `HabitEngine.applyLocalTick()` handles:
  - Completion tracking: `done:habitId:YYYY-MM-DD`
  - Streak increment: `streak:habitId`
  - XP award: `xp:total`

### Files to Modify:
1. **`lib/screens/new_home_screen.dart`**
   - Replace streak display with local `SharedPreferences` read
   - When ticking: call `HabitEngine.applyLocalTick()`

2. **`lib/screens/new_habits_screen.dart`**
   - Same as above

3. **`lib/screens/streaks_screen.dart`**
   - Remove `apiClient.getStreakSummary()` call
   - Calculate streaks from `SharedPreferences` locally:
     ```dart
     final prefs = await SharedPreferences.getInstance();
     final allKeys = prefs.getKeys();
     final habitStreaks = {};
     for (final key in allKeys) {
       if (key.startsWith('streak:')) {
         final habitId = key.split(':')[1];
         habitStreaks[habitId] = prefs.getInt(key) ?? 0;
       }
     }
     // Find max streak, display it as "overall"
     ```

### Streak Calculation Logic:
```dart
// On tick:
1. Check if already completed today → early return
2. Get yesterday's date
3. Was yesterday completed? 
   - Yes: increment streak
   - No: reset streak to 1
4. Store: streak:habitId = newStreak
5. Store: done:habitId:today = true
6. Award XP: xp:total += 15
```

---

## 📋 PHASE 4: Alarms (Native Frontend)

### Current State:
- `createAlarm()` sends to backend `/v1/alarms`
- Backend tries to manage alarms → not firing
- No local alarm system

### Target State:
- **Android**: Use `android_alarm_manager_plus` package
- **iOS**: Use local notifications
- Store alarm config in `SharedPreferences`:
  ```dart
  alarm:habitId = {
    time: "08:00",
    daysOfWeek: [1,2,3,4,5], // Mon-Fri
    mentorId: "marcus",
    intensity: 2,
    enabled: true
  }
  ```

### New Files to Create:
1. **`lib/services/local_alarm_service.dart`**
   ```dart
   class LocalAlarmService {
     Future<void> scheduleAlarm({
       required String habitId,
       required String habitName,
       required TimeOfDay time,
       required List<int> daysOfWeek,
       required String mentorId,
     }) async {
       // Use android_alarm_manager_plus
       // Schedule recurring alarm
       // Store config in SharedPreferences
     }
     
     Future<void> cancelAlarm(String habitId) async {
       // Cancel alarm
       // Remove from SharedPreferences
     }
     
     Future<List<AlarmConfig>> listAlarms() async {
       // Read all alarms from SharedPreferences
     }
   }
   ```

2. **`lib/screens/alarms_tab.dart`** (NEW TAB)
   - List all scheduled alarms
   - Toggle on/off
   - Edit time/days/mentor
   - For PRO users: custom alarm messages
   - For FREE users: default messages only

### Integration in Habit Creation:
```dart
// In new_habits_screen.dart, after creating habit:
if (data['reminderOn'] == true) {
  await LocalAlarmService().scheduleAlarm(
    habitId: created['id'],
    habitName: created['title'],
    time: TimeOfDay(hour: hour, minute: minute),
    daysOfWeek: schedule.daysOfWeek, // from HabitSchedule
    mentorId: data['mentorId'] ?? 'marcus',
  );
}
```

---

## 📋 PHASE 5: Remove Backend Dependencies

### API Methods to REMOVE (or stub):
- `apiClient.selectForToday()` → not needed
- `apiClient.deselectForToday()` → not needed
- `apiClient.getStreakSummary()` → calculate locally
- `apiClient.getAchievements()` → calculate locally
- `apiClient.createAlarm()` → use local service

### API Methods to KEEP:
- `apiClient.createHabit()` → still store in DB
- `apiClient.updateHabit()` → still store in DB
- `apiClient.deleteHabit()` → still store in DB
- `apiClient.tickHabit()` → log event for analytics
- `apiClient.getBrief()` → AI morning/evening briefs
- `apiClient.getNudge()` → AI motivational nudges
- `apiClient.sendChatMessage()` → AI chat

---

## 🚀 EXECUTION ORDER

### Step 1: Test Schedule Filtering (TODAY)
1. Modify `new_home_screen.dart` to use `getTodayItems()`
2. Create test habits with different schedules:
   - Daily
   - Weekdays only
   - Custom: starts tomorrow, ends in 3 days
3. Verify calendar shows correct dates

### Step 2: Fix Calendar UI (TODAY)
1. Update week completion rail in `new_habits_screen.dart`
2. Check `isActiveOn(date)` for each day
3. Gray out non-scheduled days

### Step 3: Migrate Streaks (TOMORROW)
1. Update all screens to use `HabitEngine`
2. Remove backend streak calls
3. Test streak increments & resets

### Step 4: Implement Local Alarms (DAY 3)
1. Add `android_alarm_manager_plus` to `pubspec.yaml`
2. Create `LocalAlarmService`
3. Create alarms tab UI
4. Test alarm firing

### Step 5: Clean Up (DAY 4)
1. Remove unused backend methods
2. Update API client
3. Test everything end-to-end

---

## ✅ SUCCESS CRITERIA

- [ ] Habit with "weekdays" schedule only appears Mon-Fri
- [ ] Habit with custom end date disappears after end date
- [ ] Calendar accurately shows scheduled/completed days
- [ ] Streaks increment correctly when completing habits
- [ ] Streaks reset when missing a day
- [ ] Alarms fire at scheduled times
- [ ] Alarms respect habit schedule (don't fire on non-scheduled days)
- [ ] No more backend dependency for today's list
- [ ] No more "habit stays on forever" bug

---

## 🔥 CRITICAL FIXES NEEDED NOW

### Fix 1: `new_home_screen.dart` Line 111
```dart
// CHANGE THIS:
final briefResult = await apiClient.getBriefToday();

// TO THIS:
final today = await apiClient.getTodayItems();
final briefResult = await apiClient.getBrief(); // for AI message only
```

### Fix 2: `new_habits_screen.dart` Line 666
```dart
// CHANGE THIS:
final isScheduled = true; // Would check if scheduled for this date

// TO THIS:
final schedule = HabitSchedule.fromJson(item['schedule']);
final isScheduled = schedule.isActiveOn(date);
```

### Fix 3: All Streak Displays
```dart
// CHANGE THIS:
Text('Streak: ${item['streak']}')

// TO THIS:
FutureBuilder<int>(
  future: SharedPreferences.getInstance().then((p) => p.getInt('streak:${item['id']}') ?? 0),
  builder: (context, snapshot) => Text('Streak: ${snapshot.data ?? 0}'),
)
```

---

**This is the complete plan. No more guessing. No more half-fixes. We implement this and it WORKS.**

