import IORedis, { Redis } from 'ioredis';
export declare function getRedis(): Redis;
export declare const redis: IORedis;
export declare function redisHealthCheck(): Promise<boolean>;
export declare function closeRedis(): Promise<void>;
