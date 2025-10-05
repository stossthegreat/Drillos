export declare class TodayService {
    /**
     * Get all items (habits + tasks) selected for today
     */
    getTodayItems(userId: string, dateString?: string): Promise<any[]>;
    /**
     * Select a habit or task for today
     */
    selectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string): Promise<{
        date: string;
        id: string;
        createdAt: Date;
        userId: string;
        habitId: string | null;
        taskId: string | null;
        order: number;
    }>;
    /**
     * Deselect (remove) a habit or task from today
     */
    deselectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string): Promise<{
        date: string;
        id: string;
        createdAt: Date;
        userId: string;
        habitId: string | null;
        taskId: string | null;
        order: number;
    }>;
}
export declare const todayService: TodayService;
