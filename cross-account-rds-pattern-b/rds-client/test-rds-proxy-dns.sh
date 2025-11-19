#!/bin/bash
set -euo pipefail

echo "=== VPC Lattice Pattern B - RDS Proxy DNS-based Connectivity Test ==="
echo "開始時刻: $(date)"
echo

# Test 1: DNS Resolution
echo "[Test 1] DNS Resolution - RDS Proxy Writer"
echo "Endpoint: pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
if command -v host &> /dev/null; then
    host pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com || echo "DNS resolution failed"
elif command -v nslookup &> /dev/null; then
    nslookup pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com || echo "DNS resolution failed"
else
    echo "No DNS tools available"
fi
echo

# Test 2: DNS Resolution Reader
echo "[Test 2] DNS Resolution - RDS Proxy Reader"
echo "Endpoint: pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
if command -v host &> /dev/null; then
    host pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com || echo "DNS resolution failed"
elif command -v nslookup &> /dev/null; then
    nslookup pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com || echo "DNS resolution failed"
else
    echo "No DNS tools available"
fi
echo

# Test 3: Database Connection - RDS Proxy Writer
echo "[Test 3] Database Connection - RDS Proxy Writer"
echo "Endpoint: pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
timeout 30 PGPASSWORD=password123 psql -h pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c "SELECT 'Test 3: RDS Proxy Writer' as test_name, current_user, inet_server_addr() as db_server_ip, version();" 2>&1 || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "Connection timeout after 30 seconds"
    else
        echo "Connection failed with exit code: $EXIT_CODE"
    fi
}
echo

# Test 4: Database Connection - RDS Proxy Reader
echo "[Test 4] Database Connection - RDS Proxy Reader"
echo "Endpoint: pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
timeout 30 PGPASSWORD=password123 psql -h pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c "SELECT 'Test 4: RDS Proxy Reader' as test_name, current_user, inet_server_addr() as db_server_ip, version();" 2>&1 || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "Connection timeout after 30 seconds"
    else
        echo "Connection failed with exit code: $EXIT_CODE"
    fi
}
echo

echo "終了時刻: $(date)"
echo "=== Test Complete ==="
