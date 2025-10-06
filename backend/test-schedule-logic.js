// TEST THE SCHEDULE LOGIC

function isScheduledToday(schedule) {
  if (!schedule || !schedule.type) return true;
  const today = new Date();
  const day = today.getDay();

  switch (schedule.type) {
    case "daily":
      return true;
    case "weekdays":
      return day >= 1 && day <= 5;
    case "everyN":
      if (!schedule.startDate || !schedule.everyN) return true;
      const start = new Date(schedule.startDate);
      const diffDays = Math.floor(
        (today.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
      );
      return diffDays % schedule.everyN === 0;
    case "custom":
      if (schedule.startDate && today < new Date(schedule.startDate)) return false;
      if (schedule.endDate && today > new Date(schedule.endDate)) return false;
      return true;
    default:
      return true;
  }
}

// TEST CASES
console.log("🧪 Testing Schedule Logic:");
console.log("Today:", new Date().toDateString());
console.log("Today day of week:", new Date().getDay(), "(0=Sunday, 1=Monday, ..., 6=Saturday)");
console.log("");

// Test 1: Daily (should always show)
console.log("1. Daily schedule:", isScheduledToday({ type: "daily" }), "✅");

// Test 2: Weekdays (depends on today)
const weekdaysResult = isScheduledToday({ type: "weekdays" });
const isWeekday = new Date().getDay() >= 1 && new Date().getDay() <= 5;
console.log("2. Weekdays schedule:", weekdaysResult, isWeekday ? "✅" : "❌ (expected, today is weekend)");

// Test 3: Custom with end date 4 days AGO (should NOT show)
const fourDaysAgo = new Date();
fourDaysAgo.setDate(fourDaysAgo.getDate() - 4);
console.log("3. Custom with end date 4 days ago:", isScheduledToday({ 
  type: "custom", 
  endDate: fourDaysAgo.toISOString().split('T')[0] 
}), "❌ (expected false)");

// Test 4: Custom with end date 4 days FROM NOW (should show)
const fourDaysFromNow = new Date();
fourDaysFromNow.setDate(fourDaysFromNow.getDate() + 4);
console.log("4. Custom with end date 4 days from now:", isScheduledToday({ 
  type: "custom", 
  endDate: fourDaysFromNow.toISOString().split('T')[0] 
}), "✅ (expected true)");

// Test 5: Custom with start date tomorrow (should NOT show)
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
console.log("5. Custom starting tomorrow:", isScheduledToday({ 
  type: "custom", 
  startDate: tomorrow.toISOString().split('T')[0] 
}), "❌ (expected false)");

// Test 6: EveryN = 2 (every other day)
console.log("6. EveryN=2 starting today:", isScheduledToday({ 
  type: "everyN", 
  everyN: 2,
  startDate: new Date().toISOString().split('T')[0]
}), "✅ (day 0, should show)");

console.log("");
console.log("🎯 If these match expectations, the logic is correct!");

