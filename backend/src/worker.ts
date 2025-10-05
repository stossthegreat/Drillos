import { bootstrapSchedulers } from "./jobs/scheduler";

(async () => {
  console.log("🧠 Scheduler worker starting...");
  try {
    await bootstrapSchedulers();
    console.log("⏰ All repeatable jobs registered!");
  } catch (err) {
    console.error("❌ Failed to bootstrap schedulers:", err);
    process.exit(1);
  }
})();
