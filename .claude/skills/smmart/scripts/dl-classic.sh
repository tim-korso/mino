#!/bin/bash
# dl-classic.sh —— 下载经典书籍/论文（DNS绕过+多通道）
# 用法: dl-classic.sh --title "书名" --author "作者"
#       dl-classic.sh --doi "10.xxx/xxxx"

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# DNS-over-HTTPS 解析——绕过DNS投毒
doh_resolve() {
  local domain=$1
  local ip=$(curl -s --max-time 3 "https://cloudflare-dns.com/dns-query?name=$domain&type=A" \
    -H "accept: application/dns-json" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Answer',[{}])[0].get('data',''))" 2>/dev/null)
  echo "$ip"
}

# 增强curl——DNS绕过+真人UA
smart_curl() {
  local domain=$1; local path=$2; local output=$3
  local ip=$(doh_resolve "$domain")
  if [ -z "$ip" ]; then
    echo -e "${RED}❌ DNS解析失败${NC}: $domain" >&2
    return 1
  fi
  curl -s --max-time 30 -L --resolve "$domain:443:$ip" \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
    -H "Accept: text/html,application/xhtml+xml,application/pdf,*/*" \
    -H "Accept-Language: en-US,en;q=0.9,zh-CN;q=0.8" \
    -o "$output" \
    "https://$domain$path" 2>/dev/null
  return $?
}

echo "📚 dl-classic —— 经典下载（DNS绕过版）"
echo ""

# ── Channel 1: Sci-Hub (论文) ──
if [ -n "$2" ] && [[ "$1" == "--doi" ]]; then
  doi="$2"
  echo "🔬 Sci-Hub: DOI $doi"
  
  for domain in sci-hub.ru sci-hub.st sci-hub.se; do
    ip=$(doh_resolve "$domain")
    [ -z "$ip" ] && continue
    
    output="/tmp/scihub-$(echo $doi | tr '/' '_').pdf"
    echo "  尝试 $domain ($ip)..."
    
    curl -s --max-time 20 -L --resolve "$domain:443:$ip" \
      -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
      -o "$output" \
      "https://$domain/$doi" 2>/dev/null
    
    size=$(stat -f%z "$output" 2>/dev/null || echo 0)
    if [ "$size" -gt 50000 ]; then
      echo -e "  ${GREEN}✅ 成功${NC}: $output ($(numfmt --to=iec $size 2>/dev/null || echo ${size}B))"
      file "$output"
      exit 0
    else
      # 检查是否是CAPTCHA
      if grep -qi "captcha\|cloudflare\|ddos" "$output" 2>/dev/null; then
        echo "  ${YELLOW}⚠️  CAPTCHA保护${NC}——自动下载不可用"
      else
        echo "  ${RED}❌ 失败${NC} (${size}B)"
      fi
    fi
  done
  echo -e "${YELLOW}💡 所有Sci-Hub镜像都返回CAPTCHA——尝试浏览器手动下载或使用@sci_hub_bot (Telegram)${NC}"
  exit 1
fi

# ── Channel 2: LibGen (书籍) ──
if [ -n "$2" ] && [[ "$1" == "--title" ]]; then
  title="$2"
  author="${4:-}"
  echo "📖 LibGen: $title"
  
  LIBGEN_IP=$(doh_resolve "libgen.li")
  if [ -z "$LIBGEN_IP" ]; then
    echo -e "${RED}❌ LibGen DNS解析失败${NC}"
    exit 1
  fi
  
  # 搜索
  query=$(echo "$title $author" | tr ' ' '+')
  echo "  搜索: $query"
  search=$(curl -s --max-time 15 --resolve "libgen.li:443:$LIBGEN_IP" \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "https://libgen.li/search.php?req=$query&res=5&view=simple&phrase=1&column=title" 2>/dev/null)
  
  if echo "$search" | grep -qi "404\|not found"; then
    echo -e "${YELLOW}⚠️  LibGen搜索404——服务器可能需要不同的Host头${NC}"
  elif [ "$(echo "$search" | wc -l)" -lt 10 ]; then
    echo -e "${YELLOW}⚠️  搜索结果为空或被拦截${NC}"
  else
    echo "  搜索返回 $(echo "$search" | wc -l) 行"
    echo "$search" | grep -i "$title" | head -3
  fi
fi

echo ""
echo -e "${YELLOW}💡 备用通道:${NC}"
echo "  📚 Google Books → TOC (可用)"
echo "  📚 Wikipedia → 概念摘要 (可用)"  
echo "  📚 Z-Library → singlelogin.re (HTTP200——但需登录)"
echo "  📚 @Z_Lib_Official_Bot (Telegram——最可靠——不受DNS影响)"
echo "  📚 @sci_hub_bot (Telegram——最可靠)"
