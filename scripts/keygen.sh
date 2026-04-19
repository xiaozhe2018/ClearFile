#!/bin/bash
# ============================================================
# ClearFile License Key Generator (HMAC-SHA256)
#
# 用法：
#   ./scripts/keygen.sh          # 生成 1 个 key
#   ./scripts/keygen.sh 10       # 生成 10 个 key
#   ./scripts/keygen.sh 50 > keys.txt  # 批量导出
# ============================================================

# ⚠️ 这个密钥必须和 App 里 LicenseKeyValidator.secret 一致
# 改了这里就要同步改 Swift 代码
SECRET="ClearFile2026!hmac@secret#key"

COUNT=${1:-1}

for i in $(seq 1 "$COUNT"); do
    # 生成 8 位随机 hex
    RANDOM_PART=$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')
    # HMAC-SHA256 签名，取前 8 位作为校验码
    SIG=$(echo -n "$RANDOM_PART" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}' | cut -c1-8 | tr '[:lower:]' '[:upper:]')
    # 格式化：CF-XXXX-XXXX-YYYY-YYYY
    R1=${RANDOM_PART:0:4}
    R2=${RANDOM_PART:4:4}
    S1=${SIG:0:4}
    S2=${SIG:4:4}
    echo "CF-${R1}-${R2}-${S1}-${S2}"
done
