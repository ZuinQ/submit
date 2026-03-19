#!/bin/bash
# ============================================
# 🚀 SETUP SCRIPT - PHASE 1 (FOR 2 REPOS)
# ============================================
# Mục đích: Cài đặt môi trường cho Phase 2 và Phase 3
# - Phase 2: Node.js, PM2, Nginx, MongoDB, Firewall
# - Phase 3: Docker, Docker Compose
# ============================================

# =======================
# CONFIG
# =======================
APP_USER="$USER"
CODE_REPO="/home/$APP_USER/code"        # Repo code
SUBMIT_REPO="/home/$APP_USER/submit"    # Repo submit
SRC_DIR="$CODE_REPO/src"                       # Source code thực tế
LOG_FILE="/tmp/setup-$(date +%Y%m%d-%H%M%S).log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_step()  { echo -e "\n${BLUE}▶ $1${NC}"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

# =======================
# CHECK SYSTEM
# =======================
check_system() {
    print_step "Checking system..."

    if ! grep -qi "ubuntu" /etc/os-release; then
        print_error "Only Ubuntu supported"
        exit 1
    fi

    if ! curl -s http://google.com &>/dev/null; then
        print_error "No internet connection"
        exit 1
    fi

    print_info "System: $(lsb_release -d | cut -f2)"
    print_info "User: $APP_USER"
    print_info "Code repo: $CODE_REPO"
    print_info "Submit repo: $SUBMIT_REPO"
    print_info "Log file: $LOG_FILE"
}

# =======================
# UPDATE SYSTEM
# =======================
update_system() {
    print_step "Updating system packages..."
    sudo apt update -y >> "$LOG_FILE" 2>&1
    sudo apt upgrade -y -o Dpkg::Options::="--force-confnew" >> "$LOG_FILE" 2>&1
    print_info "System updated"
}

# =======================
# INSTALL BASIC TOOLS
# =======================
install_basic_tools() {
    print_step "Installing basic tools..."
    sudo apt install -y \
        curl \
        git \
        build-essential \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        ufw \
        >> "$LOG_FILE" 2>&1
    print_info "Basic tools installed"
}

# =======================
# CONFIGURE FIREWALL (UFW)
# =======================
configure_firewall() {
    print_step "Configuring firewall (UFW)..."

    # Reset về mặc định (cẩn thận khi đang SSH)
    sudo ufw --force disable >> "$LOG_FILE" 2>&1
    sudo ufw --force reset >> "$LOG_FILE" 2>&1

    # Set default policies: chặn hết incoming, cho phép outgoing
    sudo ufw default deny incoming >> "$LOG_FILE" 2>&1
    sudo ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH (cực kỳ quan trọng - không thì mất kết nối!)
    sudo ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1

    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
    sudo ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1

    # KHÔNG mở port 3000 - vì dùng reverse proxy
    # sudo ufw allow 3000/tcp  # ❌ KHÔNG LÀM

    # Enable firewall (tự động đồng ý)
    echo "y" | sudo ufw enable >> "$LOG_FILE" 2>&1

    # Hiển thị status
    sudo ufw status verbose | tee -a "$LOG_FILE"

    print_info "Firewall configured: only SSH (22), HTTP (80), HTTPS (443) allowed"
}

# =======================
# INSTALL NODE.JS
# =======================
install_nodejs() {
    print_step "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >> "$LOG_FILE" 2>&1
    sudo apt install -y nodejs >> "$LOG_FILE" 2>&1

    print_info "Node.js: $(node -v)"
    print_info "npm: $(npm -v)"
}

# =======================
# INSTALL NGINX
# =======================
install_nginx() {
    print_step "Installing Nginx..."
    sudo apt install -y nginx >> "$LOG_FILE" 2>&1
    sudo systemctl enable nginx >> "$LOG_FILE" 2>&1
    sudo systemctl start nginx >> "$LOG_FILE" 2>&1
    print_info "Nginx: $(nginx -v 2>&1 | cut -d'/' -f2)"
}

# =======================
# INSTALL MONGODB
# =======================
install_mongodb() {
    print_step "Installing MongoDB 6.0..."

    UBUNTU_CODENAME=$(lsb_release -cs)

    wget -qO - https://pgp.mongodb.com/server-6.0.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg

    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/6.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list > /dev/null

    sudo apt update -y >> "$LOG_FILE" 2>&1
    sudo apt install -y mongodb-org >> "$LOG_FILE" 2>&1

    sudo systemctl enable mongod >> "$LOG_FILE" 2>&1
    sudo systemctl start mongod >> "$LOG_FILE" 2>&1

    print_info "MongoDB: $(mongod --version | grep 'db version' | cut -d' ' -f3)"
}

# =======================
# INSTALL PM2
# =======================
install_pm2() {
    print_step "Installing PM2..."
    sudo npm install -g pm2 >> "$LOG_FILE" 2>&1

    # Setup PM2 startup
    sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $APP_USER --hp /home/$APP_USER >> "$LOG_FILE" 2>&1

    print_info "PM2: $(pm2 -v)"
}

# =======================
# INSTALL DOCKER
# =======================
install_docker() {
    print_step "Installing Docker..."

    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update -y >> "$LOG_FILE" 2>&1
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >> "$LOG_FILE" 2>&1

    # Add user to docker group
    sudo usermod -aG docker $APP_USER

    # Enable and start Docker
    sudo systemctl enable docker >> "$LOG_FILE" 2>&1
    sudo systemctl start docker >> "$LOG_FILE" 2>&1

    print_info "Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
}

# =======================
# INSTALL DOCKER COMPOSE (STANDALONE)
# =======================
install_docker_compose() {
    print_step "Installing Docker Compose..."

    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)

    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Create symbolic link
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    print_info "Docker Compose: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
}

# =======================
# INSTALL PROJECT DEPENDENCIES
# =======================
install_project_deps() {
    print_step "Installing project dependencies..."

    if [ -f "$CODE_REPO/package.json" ]; then
        cd "$CODE_REPO" || exit
        npm install >> "$LOG_FILE" 2>&1
        print_info "Dependencies installed for code repo"
    else
        print_error "package.json not found in $CODE_REPO"
        print_warn "Make sure you've cloned the code repo first:"
        print_warn "git clone https://github.com/your-org/code.git $CODE_REPO"
    fi
}

# =======================
# CREATE UPLOADS DIRECTORY
# =======================
create_uploads_dir() {
    print_step "Creating uploads directory..."

    mkdir -p "$SRC_DIR/public/uploads"
    sudo chown -R $APP_USER:$APP_USER "$SRC_DIR/public"
    chmod 755 "$SRC_DIR/public/uploads"

    print_info "Uploads directory: $SRC_DIR/public/uploads"
}

# =======================
# START APP WITH PM2
# =======================
start_app() {
    print_step "Starting app with PM2..."

    if [ -f "$SRC_DIR/main.js" ]; then
        cd "$CODE_REPO" || exit
        pm2 start "$SRC_DIR/main.js" --name devops-app
        pm2 save
        print_info "App started with PM2"
        print_info "Run 'pm2 list' to check status"
    else
        print_error "main.js not found in $SRC_DIR"
    fi
}

# =======================
# VERIFY INSTALLATIONS
# =======================
verify_installations() {
    print_step "Verifying installations..."

    echo "----------------------------------------"
    echo "Node.js:     $(node -v)"
    echo "npm:         $(npm -v)"
    echo "PM2:         $(pm2 -v)"
    echo "Nginx:       $(nginx -v 2>&1 | cut -d'/' -f2)"
    echo "MongoDB:     $(mongod --version | grep 'db version' | cut -d' ' -f3)"
    echo "Docker:      $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "Docker Compose: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "----------------------------------------"

    # Check services
    echo ""
    echo "Service status:"
    sudo systemctl is-active --quiet nginx && echo "✅ Nginx" || echo "❌ Nginx"
    sudo systemctl is-active --quiet mongod && echo "✅ MongoDB" || echo "❌ MongoDB"
    sudo systemctl is-active --quiet docker && echo "✅ Docker" || echo "❌ Docker"
    pm2 list | grep -q "online" && echo "✅ PM2" || echo "❌ PM2"
    
    # Check firewall
    echo "Firewall status:"
    sudo ufw status | grep -q "active" && echo "✅ UFW active" || echo "❌ UFW inactive"
}

# =======================
# NOTES ABOUT CERTBOT
# =======================
certbot_notes() {
    print_step "📝 HTTPS Certificate (Certbot) - Manual Step"

    echo ""
    echo "Certbot KHÔNG được cài tự động vì cần domain cụ thể."
    echo ""
    echo "Để cài HTTPS cho domain của bạn, chạy các lệnh sau:"
    echo "----------------------------------------"
    echo "sudo apt install -y certbot python3-certbot-nginx"
    echo "sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com"
    echo "----------------------------------------"
    echo ""
    echo "Sau đó kiểm tra: sudo certbot certificates"
    echo "Auto-renew: sudo certbot renew --dry-run"
}

# =======================
# FIREWALL NOTES
# =======================
firewall_notes() {
    print_step "📝 Firewall Status & Commands"

    echo ""
    echo "Firewall đã được cấu hình với UFW:"
    echo "----------------------------------------"
    sudo ufw status verbose
    echo "----------------------------------------"
    echo ""
    echo "Các lệnh UFW hữu ích cho troubleshooting:"
    echo "  sudo ufw status numbered      # Xem rules có số thứ tự"
    echo "  sudo ufw delete <number>      # Xóa rule theo số"
    echo "  sudo ufw allow 22/tcp         # Thêm rule SSH (nếu quên)"
    echo "  sudo ufw disable              # Tắt firewall (chỉ khi debug)"
    echo "  sudo ufw enable               # Bật lại firewall"
    echo ""
    echo "✅ Ports allowed: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
    echo "❌ Port 3000 KHÔNG được mở - vì đã có Nginx reverse proxy"
    echo ""
    echo "📸 Đừng quên chụp ảnh 'sudo ufw status verbose' cho Phase 2!"
}

# =======================
# NOTES ABOUT REPOS
# =======================
repo_notes() {
    print_step "📁 Repository Notes"

    echo ""
    echo "Cấu trúc 2 repo của bạn:"
    echo "----------------------------------------"
    echo "Code repo:  $CODE_REPO"
    echo "Submit repo: $SUBMIT_REPO"
    echo ""
    echo "Nếu chưa clone, chạy:"
    echo "git clone https://github.com/your-org/code.git $CODE_REPO"
    echo "git clone https://github.com/your-org/submit.git $SUBMIT_REPO"
    echo "----------------------------------------"
}

# =======================
# FINAL NOTES
# =======================
final_notes() {
    echo ""
    echo "📋 CÁC BƯỚC TIẾP THEO:"
    echo "========================================="
    echo "1️⃣  Cấu hình Nginx với domain của bạn:"
    echo "   sudo cp $SUBMIT_REPO/phase2/nginx/yourdomain.conf /etc/nginx/sites-available/"
    echo "   sudo ln -s /etc/nginx/sites-available/yourdomain.conf /etc/nginx/sites-enabled/"
    echo "   sudo nginx -t && sudo systemctl reload nginx"
    echo ""
    echo "2️⃣  Cài đặt HTTPS với Certbot:"
    echo "   sudo apt install -y certbot python3-certbot-nginx"
    echo "   sudo certbot --nginx -d yourdomain.com"
    echo ""
    echo "3️⃣  Kiểm tra PM2:"
    echo "   pm2 list"
    echo "   pm2 logs devops-app"
    echo ""
    echo "4️⃣  Kiểm tra firewall:"
    echo "   sudo ufw status verbose  # Chụp ảnh cho Phase 2"
    echo ""
    echo "5️⃣  Khi chuyển sang Phase 3:"
    echo "   cd $SUBMIT_REPO/phase3"
    echo "   docker-compose up -d"
    echo "========================================="
}

# =======================
# MAIN
# =======================
main() {
    echo "========================================="
    echo "🚀 SETUP SCRIPT FOR DEVOPS PROJECT"
    echo "========================================="
    echo "Log file: $LOG_FILE"
    echo ""

    check_system
    repo_notes

    # Hỏi người dùng đã clone repo chưa
    read -p "Đã clone code repo vào $CODE_REPO chưa? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Vui lòng clone code repo trước:"
        print_warn "git clone https://github.com/your-org/code.git $CODE_REPO"
        exit 1
    fi

    update_system
    install_basic_tools
    configure_firewall           # ← ĐÃ THÊM FIREWALL
    install_nodejs
    install_nginx
    install_mongodb
    install_pm2
    install_docker
    install_docker_compose

    create_uploads_dir
    install_project_deps
    start_app

    verify_installations
    certbot_notes
    firewall_notes               # ← ĐÃ THÊM FIREWALL NOTES
    final_notes

    echo ""
    echo "========================================="
    echo "✅ SETUP COMPLETED SUCCESSFULLY"
    echo "========================================="
    echo "📝 Log file: $LOG_FILE"
    echo "🌐 App: http://$(curl -s ifconfig.me):3000"
    echo "🔑 Để dùng Docker không cần sudo: logout/login lại"
    echo "========================================="
}

main