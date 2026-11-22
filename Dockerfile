FROM node:20-bookworm-slim AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .


FROM node:20-bookworm-slim
ENV NODE_ENV=production \
    PORT=3000 \
    TZ=Asia/Seoul
WORKDIR /app

COPY --from=builder --chown=node:node /app /app

# OCR 업로드 임시 폴더
RUN mkdir -p /app/uploads && chown node:node /app/uploads

USER node

EXPOSE 3000
CMD ["node", "app.js"]
