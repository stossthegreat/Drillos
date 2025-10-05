FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy built application
COPY dist/ ./dist/
COPY prisma/ ./prisma/

# Expose port
EXPOSE 3000

# Start the scheduler worker
CMD ["node", "dist/workers/scheduler.worker.js"]