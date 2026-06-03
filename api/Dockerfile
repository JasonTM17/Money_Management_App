# syntax=docker/dockerfile:1

FROM node:22-alpine AS deps
WORKDIR /app
COPY api/package*.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY api/package*.json ./
COPY api/tsconfig.json ./
COPY api/tsconfig.build.json ./
COPY api/prisma.config.ts ./
COPY api/prisma ./prisma
COPY api/src ./src
RUN npx prisma generate
RUN npm run build

FROM builder AS tools
ENV NODE_ENV=development

FROM node:22-alpine AS production-deps
WORKDIR /app
COPY api/package*.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS runtime
WORKDIR /app
ARG REVISION=local
LABEL org.opencontainers.image.source="https://github.com/JasonTM17/Money_Management_App"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.revision="$REVISION"
ENV NODE_ENV=production
RUN addgroup -S app && adduser -S app -G app
COPY --from=production-deps /app/package*.json ./
COPY --from=production-deps /app/node_modules ./node_modules
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD node -e "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/src/main.js"]
