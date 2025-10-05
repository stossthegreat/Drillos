import { Queue } from "bullmq";
export declare const schedulerQueue: Queue<any, any, string, any, any, string>;
export declare function bootstrapSchedulers(): Promise<void>;
