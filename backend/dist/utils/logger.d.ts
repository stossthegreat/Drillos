import pino from 'pino';
export declare const logger: pino.Logger<never, boolean>;
export declare function childLogger(bindings: Record<string, any>): pino.Logger<never, boolean>;
