"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const scheduler_1 = require("./jobs/scheduler");
(async () => {
    console.log("🧠 Scheduler worker starting...");
    try {
        await (0, scheduler_1.bootstrapSchedulers)();
        console.log("⏰ All repeatable jobs registered!");
    }
    catch (err) {
        console.error("❌ Failed to bootstrap schedulers:", err);
        process.exit(1);
    }
})();
