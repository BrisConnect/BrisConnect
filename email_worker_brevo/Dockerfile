FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

ENV NODE_ENV=production
ENV POLL_INTERVAL_MS=5000
ENV MAX_BATCH_SIZE=20

CMD ["node", "index.js"]
