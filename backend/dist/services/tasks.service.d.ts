type CreateTaskInput = {
    title: string;
    description?: string;
    dueDate?: Date;
    priority?: number;
    category?: string;
};
type UpdateTaskInput = {
    title?: string;
    description?: string;
    dueDate?: Date;
    priority?: number;
    category?: string;
    completed?: boolean;
    completedAt?: Date;
};
export declare class TasksService {
    list(userId: string, includeCompleted?: boolean): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        description: string | null;
        dueDate: Date | null;
        priority: number;
        category: string | null;
        completed: boolean;
        completedAt: Date | null;
    }[]>;
    getById(taskId: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        description: string | null;
        dueDate: Date | null;
        priority: number;
        category: string | null;
        completed: boolean;
        completedAt: Date | null;
    }>;
    create(userId: string, input: CreateTaskInput): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        description: string | null;
        dueDate: Date | null;
        priority: number;
        category: string | null;
        completed: boolean;
        completedAt: Date | null;
    }>;
    update(taskId: string, userId: string, updates: UpdateTaskInput): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        description: string | null;
        dueDate: Date | null;
        priority: number;
        category: string | null;
        completed: boolean;
        completedAt: Date | null;
    }>;
    complete(taskId: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        description: string | null;
        dueDate: Date | null;
        priority: number;
        category: string | null;
        completed: boolean;
        completedAt: Date | null;
    }>;
    delete(taskId: string, userId: string): Promise<{
        ok: boolean;
        deleted: {
            id: string;
            title: string;
        };
    }>;
}
export declare const tasksService: TasksService;
export {};
