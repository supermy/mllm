#!/bin/bash

set -e

echo "==== 配置 HTTPS SSL 证书 ===="

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以 root 权限运行此脚本"
    exit 1
fi

# 设置变量
DOMAIN_OR_IP=${1:-"localhost"}  # 支持域名或 IP
SSL_DIR="/etc/ssl/private"
CERT_DIR="/etc/ssl/certs"
OPENRESTY_CONF_DIR="/usr/local/openresty/nginx/conf"

# 创建必要的目录
mkdir -p $SSL_DIR $CERT_DIR

# 判断是否为 IP 地址
if [[ $DOMAIN_OR_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IS_IP=1
else
    IS_IP=0
fi

# 生成 openssl 配置文件，支持 subjectAltName
OPENSSL_CNF="/tmp/openssl_ssl.cnf"
cat > $OPENSSL_CNF <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = CN
ST = Beijing
L = Beijing
O = AI Platform
OU = Dev
CN = ${DOMAIN_OR_IP}
[v3_req]
subjectAltName = @alt_names
[alt_names]
EOF
if [ $IS_IP -eq 1 ]; then
    echo "IP.1 = ${DOMAIN_OR_IP}" >> $OPENSSL_CNF
else
    echo "DNS.1 = ${DOMAIN_OR_IP}" >> $OPENSSL_CNF
fi

# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $SSL_DIR/nginx-selfsigned.key \
    -out $CERT_DIR/nginx-selfsigned.crt \
    -config $OPENSSL_CNF \
    -extensions v3_req

rm -f $OPENSSL_CNF

echo "自签名证书已生成:"
echo "私钥: $SSL_DIR/nginx-selfsigned.key"
echo "证书: $CERT_DIR/nginx-selfsigned.crt"

# 创建 SSL 配置文件
echo "正在创建 SSL 配置..."
cat > $OPENRESTY_CONF_DIR/ssl.conf << EOF
# SSL 配置
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

# SSL 会话配置
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
# 已在 http 块统一配置 resolver

# 安全头部
add_header Strict-Transport-Security "max-age=63072000" always;
EOF

echo "SSL 配置文件已创建: $OPENRESTY_CONF_DIR/ssl.conf"

# 设置证书权限
chmod 644 $CERT_DIR/nginx-selfsigned.crt
chmod 600 $SSL_DIR/nginx-selfsigned.key

echo "==== SSL 配置完成 ===="
echo "请确保在 nginx.conf 中包含了 ssl.conf，并启用了 HTTPS 监听。"
echo "如果使用了自签名证书，请在客户端/浏览器中添加信任。"
