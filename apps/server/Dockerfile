# Build from the repo root:  docker build -f apps/server/Dockerfile -t shaxmat-server .
FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
COPY packages/chess-core/package.json packages/chess-core/
COPY apps/server/package.json apps/server/
COPY apps/web/package.json apps/web/
RUN npm ci --omit=dev --ignore-scripts -w @shaxmat/server -w @shaxmat/chess-core
COPY packages/chess-core/src packages/chess-core/src
COPY apps/server/src apps/server/src
USER node
EXPOSE 8080
# Node 24 runs the TypeScript sources directly (type stripping), no build step.
CMD ["node", "apps/server/src/index.ts"]
