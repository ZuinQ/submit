# ============================================
# 🐳 DOCKERFILE - PHASE 3
# ============================================
# Sử dụng Node.js 20 Alpine (nhẹ, bảo mật)
FROM node:20-alpine

# Cài đặt các package cần thiết
RUN apk add --no-cache tini

# Tạo user non-root để chạy ứng dụng
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Tạo working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Cài dependencies (chỉ production)
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Tạo thư mục uploads và phân quyền
RUN mkdir -p /app/public/uploads && \
    chown -R nodejs:nodejs /app

# Chuyển sang user non-root
USER nodejs

# Sử dụng tini để quản lý process
ENTRYPOINT ["/sbin/tini", "--"]

# Expose port
EXPOSE 3000

# Chạy ứng dụng
CMD ["node", "src/main.js"]
