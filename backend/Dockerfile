# Use Node.js LTS
FROM node:20-alpine

WORKDIR /app

# Copy package.json + lock first
COPY package*.json ./
COPY tsconfig.json ./
COPY prisma ./prisma

RUN npm install

# Copy all source
COPY . .

# Build TS -> JS
RUN npm run build

# Run Prisma migrations on startup
CMD npx prisma migrate deploy && node dist/server.js
