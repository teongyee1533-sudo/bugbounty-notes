#!/bin/bash
# ============================================================
#  DVWA 一键安装脚本  (Linux Lite / Ubuntu / Debian)
#  用法:            sudo bash install_dvwa.sh
#  自定义数据库密码: DB_PASS='你的密码' sudo -E bash install_dvwa.sh
# ============================================================

set -euo pipefail

# ---------- 可配置项 ----------
DB_NAME="dvwa"
DB_USER="dvwa"
DB_PASS="${DB_PASS:-p@ssw0rd}"     # 本地靶场用；可被环境变量覆盖
WEB_ROOT="/var/www/html"

# ---------- 检查 root ----------
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行: sudo bash install_dvwa.sh"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/8] 更新软件源并安装依赖..."
apt update
apt install -y apache2 mariadb-server mariadb-client \
    php php-mysqli php-gd php-mbstring php-xml php-curl \
    libapache2-mod-php git curl

echo "[2/8] 启动 MariaDB 服务..."
systemctl start mariadb
systemctl enable mariadb

echo "[3/8] 创建 DVWA 数据库和用户..."
mysql -u root <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
DROP USER IF EXISTS '${DB_USER}'@'localhost';
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "[4/8] 下载 DVWA 源码..."
cd "${WEB_ROOT}"
if [ -d dvwa ]; then
    echo "检测到已有 dvwa 目录，删除旧版本..."
    rm -rf dvwa
fi
git clone https://github.com/digininja/DVWA.git dvwa

echo "[5/8] 配置 DVWA 数据库连接..."
cd "${WEB_ROOT}/dvwa/config"
cp config.inc.php.dist config.inc.php
sed -i "s/^\$_DVWA\[ 'db_server' \].*/\$_DVWA[ 'db_server' ] = '127.0.0.1';/"     config.inc.php
sed -i "s/^\$_DVWA\[ 'db_database' \].*/\$_DVWA[ 'db_database' ] = '${DB_NAME}';/" config.inc.php
sed -i "s/^\$_DVWA\[ 'db_user' \].*/\$_DVWA[ 'db_user' ] = '${DB_USER}';/"         config.inc.php
sed -i "s/^\$_DVWA\[ 'db_password' \].*/\$_DVWA[ 'db_password' ] = '${DB_PASS}';/" config.inc.php

echo "[6/8] 设置文件权限..."
chown -R www-data:www-data "${WEB_ROOT}/dvwa"
chmod -R 755 "${WEB_ROOT}/dvwa"
chmod 775 "${WEB_ROOT}/dvwa/hackable/uploads"

mkdir -p "${WEB_ROOT}/dvwa/external/phpids/0.6/lib/IDS/tmp"
touch "${WEB_ROOT}/dvwa/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt"
chown www-data:www-data "${WEB_ROOT}/dvwa/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt"
chmod 664 "${WEB_ROOT}/dvwa/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt"

echo "[7/8] 配置 PHP (开启 allow_url_include)..."
PHP_INI=$(find /etc/php -path "*/apache2/php.ini" | sort -V | tail -n 1 || true)
if [ -n "${PHP_INI:-}" ] && [ -f "$PHP_INI" ]; then
    sed -i -E 's/^;?[[:space:]]*allow_url_fopen[[:space:]]*=.*/allow_url_fopen = On/'     "$PHP_INI"
    sed -i -E 's/^;?[[:space:]]*allow_url_include[[:space:]]*=.*/allow_url_include = On/' "$PHP_INI"
    echo "已修改: $PHP_INI"
else
    echo "未找到 Apache 的 php.ini，请手动设置 allow_url_include = On"
fi

echo "[8/8] 检查并重启 Apache..."
apache2ctl configtest
systemctl restart apache2

echo ""
echo "============================================"
echo "  DVWA 安装完成！"
echo "  访问:   http://localhost/dvwa/setup.php"
echo "  登录:   http://localhost/dvwa/login.php"
echo "  账号:   admin  /  密码: password"
echo "  首次访问 setup.php 请点 [Create / Reset Database]"
echo "  注意:   DVWA 含故意漏洞，切勿部署到公网！"
echo "============================================"
