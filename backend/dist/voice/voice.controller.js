const PRESET_MAP = {
    'alarm_wake': 'presets/alarm_wake.mp3',
    'streak_save': 'presets/streak_save.mp3',
    'praise_30_day': 'presets/praise_30_day.mp3',
};
function publicUrlForPreset(key) {
    const endpoint = (process.env.S3_ENDPOINT || '').replace(/\/+$/, '');
    const bucket = process.env.S3_BUCKET || 'voice';
    if (!endpoint)
        return `https://example.invalid/${bucket}/${key}`;
    return `${endpoint}/${bucket}/${key}`;
}
export default async function voiceRoutes(fastify, _opts) {
    fastify.route({
        method: 'GET',
        url: '/v1/voice/preset/:id',
        schema: {
            tags: ['Voice'],
            summary: 'Get preset audio URL',
            params: {
                type: 'object',
                required: ['id'],
                properties: { id: { type: 'string' } },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        url: { type: 'string' },
                        expiresAt: { type: 'string' },
                    },
                },
                404: {
                    type: 'object',
                    properties: {
                        error: { type: 'string' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const { id } = req.params;
            const key = PRESET_MAP[id];
            if (!key) {
                return reply.code(404).send({ error: 'Preset not found' });
            }
            const url = publicUrlForPreset(key);
            const expiresAt = new Date(Date.now() + 3600_000).toISOString();
            reply.send({ url, expiresAt });
        },
    });
}
//# sourceMappingURL=voice.controller.js.map