# Use Node.js LTS
FROM node:20-alpine

WORKDIR /app

# Copy package.json + lock first
COPY package*.json ./
COPY tsconfig.json ./
COPY prisma ./prisma

# Install ALL dependencies (including dev dependencies for build)
RUN npm ci

# Copy all source
COPY . .

# Build TS -> JS (with environment set for build)
ENV NODE_ENV=build
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production

# Expose port
EXPOSE 8080

# Run Prisma migrations on startup
CMD npx prisma migrate deploy && node dist/server.js
