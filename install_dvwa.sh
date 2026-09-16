#!/bin/bash
# DVWA 一键安装脚本 for Linux Lite / Ubuntu / Debian
# 运行方式: sudo bash install_dvwa.sh

set -e

echo "========================================"
echo "  DVWA 一键安装脚本"
echo "  适用于 Linux Lite / Ubuntu / Debian"
echo "========================================"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本: sudo bash install_dvwa.sh"
    exit 1
fi

# 获取当前登录的普通用户名（用于设置权限）
SUDO_USER_NAME=${SUDO_USER:-$USER}

echo "[1/8] 更新软件源并安装依赖..."
apt update
apt install -y apache2 mariadb-server mariadb-client php php-mysqli php-gd libapache2-mod-php git curl

echo ""
echo "[2/8] 启动 MariaDB 服务..."
systemctl start mariadb
systemctl enable mariadb

echo ""
echo "[3/8] 创建 DVWA 数据库和用户..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';
GRANT ALL ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
EOF

echo ""
echo "[4/8] 下载 DVWA 源码..."
cd /var/www/html
if [ -d "dvwa" ]; then
    echo "检测到已有 dvwa 目录，正在删除旧版本..."
    rm -rf dvwa
fi
git clone https://github.com/digininja/DVWA.git dvwa

echo ""
echo "[5/8] 配置 DVWA 数据库连接..."
cd /var/www/html/dvwa/config
cp config.inc.php.dist config.inc.php
sed -i "s/\$_DVWA\[ 'db_server' \]\s*=\s*'127.0.0.1';/\$_DVWA[ 'db_server' ] = '127.0.0.1';/" config.inc.php
sed -i "s/\$_DVWA\[ 'db_user' \]\s*=\s*'dvwa';/\$_DVWA[ 'db_user' ] = 'dvwa';/" config.inc.php
sed -i "s/\$_DVWA\[ 'db_password' \]\s*=\s*'p@ssw0rd';/\$_DVWA[ 'db_password' ] = 'p@ssw0rd';/" config.inc.php
sed -i "s/\$_DVWA\[ 'db_database' \]\s*=\s*'dvwa';/\$_DVWA[ 'db_database' ] = 'dvwa';/" config.inc.php

echo ""
echo "[6/8] 设置文件权限..."
chown -R www-data:www-data /var/www/html/dvwa
chmod 757 /var/www/html/dvwa/hackable/uploads
mkdir -p /var/www/html/dvwa/external/phpids/0.6/lib/IDS/tmp
chmod 646 /var/www/html/dvwa/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt 2>/dev/null || true

echo ""
echo "[7/8] 配置 PHP (开启 allow_url_include)..."
PHP_INI=$(find /etc/php -name "php.ini" -path "*/apache2/*" | head -n 1)
if [ -n "$PHP_INI" ]; then
    sed -i 's/allow_url_fopen = Off/allow_url_fopen = On/' "$PHP_INI"
    sed -i 's/allow_url_include = Off/allow_url_include = On/' "$PHP_INI"
    echo "已修改: $PHP_INI"
else
    echo "⚠️ 未找到 php.ini，请手动配置 allow_url_include = On"
fi

echo ""
echo "[8/8] 重启 Apache 服务..."
systemctl restart apache2

echo ""
echo "========================================"
echo "  ✅ DVWA 安装完成！"
echo "========================================"
echo ""
echo "📌 访问地址: http://localhost/dvwa/setup.php"
echo "📌 登录地址: http://localhost/dvwa/login.php"
echo "📌 用户名:   admin"
echo "📌 密码:     password"
echo ""
echo "⚠️  首次访问 setup.php 后，请点击页面底部的"
echo "   【Create / Reset Database】按钮初始化数据库"
echo ""
echo "⚠️  安全提醒: DVWA 包含大量故意设计的漏洞，"
echo "   请勿部署在公网或生产环境中！"
echo ""
