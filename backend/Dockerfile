# OneTap backend — portable container image.
# Works on Render, Fly.io, Railway, Google Cloud Run, etc. See DEPLOY.md.
FROM node:20-alpine
WORKDIR /app

# Install dependencies first for better layer caching. `tsx` runs the TypeScript directly
# and lives in devDependencies, so install everything (do NOT use --omit=dev).
COPY package.json package-lock.json* ./
RUN npm install

# App source.
COPY . .

ENV NODE_ENV=production
ENV HOST=0.0.0.0
# Most hosts inject their own PORT; config.ts reads it. 8080 is the local default.
EXPOSE 8080

# Runs "tsx src/index.ts" (see package.json "start").
CMD ["npm", "start"]
