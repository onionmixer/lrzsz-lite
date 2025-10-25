# lrzsz-lite 테스트 가이드

## 개요

이 문서는 PTY 체크를 제거한 lrzsz-lite 바이너리의 telnet socket 연결 환경에서의 테스트 시나리오를 제공합니다.

**테스트 대상**: ./bin/ 디렉토리의 컴파일된 바이너리
- `lrz` (receive: rz, ry, rx)
- `lsz` (send: sz, sy, sx)

**테스트 목적**: TCP socket 연결을 통한 XMODEM, YMODEM, ZMODEM 프로토콜의 송수신 기능 검증

## 테스트 환경 준비

### 필수 도구 설치

```bash
# Ubuntu/Debian
sudo apt-get install socat netcat-openbsd

# Fedora/RHEL
sudo dnf install socat nmap-ncat

# macOS
brew install socat netcat
```

### 테스트 디렉토리 구조

```bash
mkdir -p test_area/{send,recv}
cd test_area
```

### 테스트 파일 생성

```bash
# 다양한 크기의 테스트 파일 생성
dd if=/dev/zero of=send/test_empty.bin bs=1 count=0        # 0 bytes
dd if=/dev/urandom of=send/test_128.bin bs=128 count=1     # 128 bytes
dd if=/dev/urandom of=send/test_1K.bin bs=1K count=1       # 1 KB
dd if=/dev/urandom of=send/test_10K.bin bs=1K count=10     # 10 KB
dd if=/dev/urandom of=send/test_100K.bin bs=1K count=100   # 100 KB
dd if=/dev/urandom of=send/test_1M.bin bs=1M count=1       # 1 MB

# 텍스트 파일
echo "Hello ZMODEM Test" > send/test_text.txt

# 체크섬 저장
cd send
md5sum *.bin *.txt > ../checksums_original.txt
cd ..
```

---

## 테스트 시나리오

### 포트 설정

```bash
# 테스트용 TCP 포트
TEST_PORT=12345
LRZSZ_BIN="../bin"
```

---

## 1. ZMODEM 프로토콜 테스트

ZMODEM은 가장 진보된 프로토콜로, 에러 복구와 재개 기능을 지원합니다.

### 1.1 ZMODEM 송신 테스트 (sz → rz)

**터미널 1 (수신측)**:
```bash
cd test_area/recv
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/rz -v"
```

**터미널 2 (송신측)**:
```bash
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/sz -v test_1K.bin"
```

**검증**:
```bash
cd test_area/recv
ls -lh test_1K.bin
md5sum test_1K.bin
# 원본과 비교
cd ../send
md5sum test_1K.bin
```

### 1.2 ZMODEM 수신 테스트 (rz ← sz)

**터미널 1 (송신측 서버)**:
```bash
cd test_area/send
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/sz -v test_10K.bin"
```

**터미널 2 (수신측 클라이언트)**:
```bash
cd test_area/recv
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/rz -v"
```

**검증**:
```bash
cd test_area/recv
md5sum test_10K.bin
```

### 1.3 ZMODEM 다중 파일 전송

```bash
# 터미널 1 (수신)
cd test_area/recv
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/rz -v"

# 터미널 2 (송신 - 여러 파일)
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/sz -v test_1K.bin test_10K.bin test_text.txt"
```

---

## 2. YMODEM 프로토콜 테스트

YMODEM은 배치 전송과 파일명 전송을 지원합니다.

### 2.1 YMODEM 송신 테스트 (sy → ry)

**터미널 1 (수신)**:
```bash
cd test_area/recv
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lrz -y -v"
```

**터미널 2 (송신)**:
```bash
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lsz -y -v test_1K.bin"
```

**검증**:
```bash
cd test_area/recv
md5sum test_1K.bin
```

### 2.2 YMODEM 수신 테스트 (ry ← sy)

**터미널 1 (송신 서버)**:
```bash
cd test_area/send
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lsz -y -v test_100K.bin"
```

**터미널 2 (수신 클라이언트)**:
```bash
cd test_area/recv
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lrz -y -v"
```

### 2.3 YMODEM 배치 전송 (--ymodem)

```bash
# 터미널 1 (수신)
cd test_area/recv
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lrz --ymodem -v"

# 터미널 2 (송신 - 여러 파일)
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lsz --ymodem -v test_1K.bin test_10K.bin"
```

---

## 3. XMODEM 프로토콜 테스트

XMODEM은 가장 단순한 프로토콜로, 단일 파일만 전송 가능합니다.

**중요**: XMODEM은 빈 파일(0 bytes)을 전송할 수 없습니다.

### 3.1 XMODEM 송신 테스트 (sx → rx)

**터미널 1 (수신)**:
```bash
cd test_area/recv
# XMODEM은 파일명을 전송하지 않으므로 수동 지정 필요
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lrz -X -v test_1K.bin"
```

**터미널 2 (송신)**:
```bash
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lsz -X -v test_1K.bin"
```

**검증**:
```bash
cd test_area/recv
md5sum test_1K.bin
```

### 3.2 XMODEM 수신 테스트 (rx ← sx)

**터미널 1 (송신 서버)**:
```bash
cd test_area/send
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lsz -X -v test_128.bin"
```

**터미널 2 (수신 클라이언트)**:
```bash
cd test_area/recv
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lrz -X -v test_128.bin"
```

### 3.3 XMODEM-1K 테스트 (--xmodem)

XMODEM-1K는 1024 바이트 블록을 사용합니다:

```bash
# 터미널 1 (수신)
cd test_area/recv
socat TCP-LISTEN:12345,reuseaddr EXEC:"$LRZSZ_BIN/lrz --xmodem -v test_10K.bin"

# 터미널 2 (송신)
cd test_area/send
socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/lsz --xmodem -v test_10K.bin"
```

---

## 4. 자동화 테스트 스크립트

모든 프로토콜을 자동으로 테스트하려면 제공된 스크립트를 사용하세요:

```bash
./test_lrzsz.sh
```

스크립트는 다음을 수행합니다:
- 각 프로토콜(ZMODEM, YMODEM, XMODEM)별 파일 전송
- MD5 체크섬 검증
- 성공/실패 리포트

---

## 5. 실제 Telnet 환경 테스트

### 5.1 SSH 포트 포워딩을 통한 테스트

**로컬 머신 (송신)**:
```bash
# SSH로 원격 호스트의 rz 실행
ssh user@remote-host "cd /tmp && /path/to/lrz -v" < <(./bin/lsz -v test_file.bin)
```

### 5.2 Netcat을 사용한 간단한 테스트

**호스트 A (수신)**:
```bash
nc -l -p 12345 | ./bin/lrz -v
```

**호스트 B (송신)**:
```bash
./bin/lsz -v test_file.bin | nc host-a 12345
```

### 5.3 실제 Telnet 데몬 환경

만약 telnetd가 실행 중이라면:

```bash
# telnet으로 연결 후
telnet remote-host

# 연결 후 수신
rz -v

# 로컬에서 파일 송신 (터미널 에뮬레이터 지원 필요)
# 또는 스크립트로 자동화
```

---

## 6. PTY 없는 환경 검증

PTY 체크 제거 패치가 제대로 적용되었는지 확인:

```bash
# stdin이 TTY가 아닌 환경에서 테스트
echo | ./bin/lsz -v test_file.bin > /tmp/zmodem_output.dat 2>&1

# 오류 없이 실행되어야 함
echo $?  # 0이면 성공

# ZMODEM 헤더 확인
hexdump -C /tmp/zmodem_output.dat | head -20
# "**\x18B" 또는 ZRQINIT 시퀀스가 보여야 함
```

### PTY 없는 파이프 테스트

```bash
# 파이프를 통한 전송 (PTY 없음)
./bin/lsz -v test_file.bin < /dev/null | ./bin/lrz -v 2>&1

# 리다이렉션 테스트
./bin/lsz -v test_file.bin < /dev/null > /tmp/transfer.dat 2>&1
```

---

## 7. 프로토콜별 옵션

### ZMODEM (sz/rz)
```
-v    Verbose (상세 출력)
-b    Binary mode
-e    Escape control characters
-y    Yes, overwrite existing files
-a    ASCII 모드 (텍스트 파일)
-r    Resume interrupted transfer (재개)
-w N  Window size (패킷 창 크기)
```

### YMODEM (sy/ry)
```
-y, --ymodem    YMODEM 모드
-v              Verbose
-b              Binary mode
```

### XMODEM (sx/rx)
```
-X, --xmodem    XMODEM 모드
--xmodem        XMODEM-1K 모드
-v              Verbose
```

---

## 8. 검증 및 문제 해결

### 체크섬 검증

```bash
# 전송 전
md5sum test_area/send/test_file.bin

# 전송 후
md5sum test_area/recv/test_file.bin

# 비교
diff <(md5sum test_area/send/test_file.bin) <(md5sum test_area/recv/test_file.bin)
```

### 전송 속도 측정

```bash
# 시간 측정
time socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/sz -v test_1M.bin"
```

### 일반적인 문제

**문제 1**: "Connection refused"
```bash
# 해결: 수신측이 먼저 실행되었는지 확인
# 포트가 사용 중인지 확인
netstat -an | grep 12345
```

**문제 2**: "rz: timeout"
```bash
# 해결: 수신측과 송신측의 타이밍 확인
# socat에 타임아웃 옵션 추가
socat -T 30 TCP-LISTEN:12345,reuseaddr EXEC:"..."
```

**문제 3**: 파일이 전송되지 않음
```bash
# 디버그 모드로 실행
./bin/lsz -vv test_file.bin

# 로그 확인
strace -o /tmp/sz.log ./bin/lsz -v test_file.bin
```

**문제 4**: XMODEM에서 빈 파일 오류
```bash
# XMODEM은 0바이트 파일을 지원하지 않음
# YMODEM 또는 ZMODEM 사용 권장
```

---

## 9. 성능 테스트

### 대용량 파일 테스트

```bash
# 10MB 파일 생성
dd if=/dev/urandom of=test_area/send/test_10M.bin bs=1M count=10

# ZMODEM으로 전송 및 시간 측정
time socat TCP:localhost:12345 EXEC:"$LRZSZ_BIN/sz -v test_10M.bin"
```

### 프로토콜별 성능 비교

| 프로토콜 | 블록 크기 | 오류 검출 | 재개 기능 | 배치 전송 | 속도 |
|---------|---------|---------|---------|---------|------|
| XMODEM  | 128B    | Checksum | No     | No      | 느림 |
| XMODEM-1K | 1024B | CRC-16  | No     | No      | 보통 |
| YMODEM  | 1024B   | CRC-16  | No     | Yes     | 빠름 |
| ZMODEM  | 가변    | CRC-32  | Yes    | Yes     | 매우 빠름 |

---

## 10. CI/CD 통합 예시

### GitHub Actions 워크플로우 예시

```yaml
name: lrzsz-lite Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install dependencies
        run: sudo apt-get install -y socat

      - name: Create test files
        run: |
          mkdir -p test_area/{send,recv}
          dd if=/dev/urandom of=test_area/send/test_1K.bin bs=1K count=1
          dd if=/dev/urandom of=test_area/send/test_10K.bin bs=1K count=10

      - name: Run ZMODEM test
        run: ./test_lrzsz.sh

      - name: Verify checksums
        run: |
          cd test_area/recv
          md5sum *.bin
```

---

## 11. 보안 고려사항

### 안전한 사용

1. **신뢰할 수 있는 네트워크에서만 사용**: ZMODEM 프로토콜은 암호화되지 않습니다.
2. **방화벽 규칙**: 테스트 포트를 로컬호스트로 제한
   ```bash
   # iptables 예시
   iptables -A INPUT -p tcp --dport 12345 -s 127.0.0.1 -j ACCEPT
   iptables -A INPUT -p tcp --dport 12345 -j DROP
   ```
3. **파일 권한**: 수신 디렉토리의 권한 확인
   ```bash
   chmod 700 test_area/recv
   ```

### SSH 터널링 사용 권장

```bash
# SSH 터널을 통한 안전한 전송
ssh -L 12345:localhost:12345 user@remote-host

# 로컬에서 전송
socat TCP:localhost:12345 EXEC:"./bin/lsz -v test_file.bin"
```

---

## 12. 예상 결과

### 성공 케이스

```
ZMODEM Transfer:
Sending test_1K.bin, 1024 bytes
Bytes Sent:   1024   BPS:12345

File transfer complete.
```

### MD5 체크섬 일치

```bash
# 송신측
md5sum test_1K.bin
a1b2c3d4e5f6... test_1K.bin

# 수신측
md5sum test_1K.bin
a1b2c3d4e5f6... test_1K.bin
```

---

## 부록 A: 빠른 테스트 체크리스트

- [ ] ZMODEM 송신 (sz → rz)
- [ ] ZMODEM 수신 (rz ← sz)
- [ ] ZMODEM 다중 파일
- [ ] YMODEM 송신 (sy → ry)
- [ ] YMODEM 수신 (ry ← sy)
- [ ] YMODEM 배치 전송
- [ ] XMODEM 송신 (sx → rx)
- [ ] XMODEM 수신 (rx ← sx)
- [ ] XMODEM-1K 전송
- [ ] PTY 없는 환경 테스트
- [ ] 체크섬 검증
- [ ] 대용량 파일 (1MB+) 테스트

---

## 부록 B: 참고 자료

- ZMODEM 프로토콜 사양: [ITU-T Recommendation T.30](https://www.itu.int/)
- lrzsz 원본 문서: https://www.ohse.de/uwe/software/lrzsz.html
- XMODEM/YMODEM 사양: http://web.archive.org/web/20100929013015/http://www.techfest.com/hardware/modem/xymodem.htm

---

## 부록 C: 실제 테스트 결과

### 테스트 실행 정보

- **테스트 일시**: 2025-10-26
- **테스트 환경**: Linux (Ubuntu/Debian)
- **테스트 도구**: socat, bash
- **자동화 스크립트**: `run_tests.sh`

### 자동화 테스트 스크립트 실행

```bash
# 테스트 스크립트 실행
./run_tests.sh
```

### 테스트 결과 요약

```
=========================================
Test Summary
=========================================
Passed: 11
Failed: 0
Total: 11

All tests passed!
```

### 프로토콜별 상세 결과

#### ZMODEM 프로토콜 (4/4 통과)

| 파일명 | 크기 | 원본 MD5 | 수신 MD5 | 결과 |
|--------|------|----------|----------|------|
| test_text.txt | 18 bytes | 779b3429f4397c6944d92d247574e460 | 779b3429f4397c6944d92d247574e460 | ✓ PASS |
| test_128.bin | 128 bytes | f7d23e7263814c262c863c31b9a6971a | f7d23e7263814c262c863c31b9a6971a | ✓ PASS |
| test_1K.bin | 1 KB | 41302cdb5e3a062b9bc1856ea82818ea | 41302cdb5e3a062b9bc1856ea82818ea | ✓ PASS |
| test_10K.bin | 10 KB | 9b8936a8be1832c11103d6baa240f76c | 9b8936a8be1832c11103d6baa240f76c | ✓ PASS |

**ZMODEM 특징 확인:**
- ✓ 파일명 자동 전송
- ✓ 다양한 크기 파일 전송
- ✓ 빠른 전송 속도 (최대 20 Mbps)
- ✓ CRC-32 체크섬 검증

#### YMODEM 프로토콜 (4/4 통과)

| 파일명 | 크기 | 원본 MD5 | 수신 MD5 | 결과 |
|--------|------|----------|----------|------|
| test_text.txt | 18 bytes | 779b3429f4397c6944d92d247574e460 | 779b3429f4397c6944d92d247574e460 | ✓ PASS |
| test_128.bin | 128 bytes | f7d23e7263814c262c863c31b9a6971a | f7d23e7263814c262c863c31b9a6971a | ✓ PASS |
| test_1K.bin | 1 KB | 41302cdb5e3a062b9bc1856ea82818ea | 41302cdb5e3a062b9bc1856ea82818ea | ✓ PASS |
| test_10K.bin | 10 KB | 9b8936a8be1832c11103d6baa240f76c | 9b8936a8be1832c11103d6baa240f76c | ✓ PASS |

**YMODEM 특징 확인:**
- ✓ 파일명 전송 지원
- ✓ 1024 바이트 블록 사용
- ✓ CRC-16 체크섬 검증
- ✓ 안정적인 전송

#### XMODEM 프로토콜 (3/3 통과)

| 파일명 | 크기 | 원본 MD5 | 수신 MD5 | 결과 |
|--------|------|----------|----------|------|
| test_empty.bin | 0 bytes | - | - | SKIPPED (미지원) |
| test_128.bin | 128 bytes | f7d23e7263814c262c863c31b9a6971a | f7d23e7263814c262c863c31b9a6971a | ✓ PASS |
| test_1K.bin | 1 KB | 41302cdb5e3a062b9bc1856ea82818ea | 41302cdb5e3a062b9bc1856ea82818ea | ✓ PASS |
| test_10K.bin | 10 KB | 9b8936a8be1832c11103d6baa240f76c | 9b8936a8be1832c11103d6baa240f76c | ✓ PASS |

**XMODEM 특징 확인:**
- ✓ 128 바이트 블록 전송
- ✓ 체크섬 검증
- ✓ 수동 파일명 지정 필요
- ✓ 빈 파일 미지원 (예상된 동작)

### PTY 없는 환경 검증 결과

```bash
# stdin이 TTY가 아닌 환경에서 테스트
echo | ./bin/lsz -v test_1K.bin > /tmp/zmodem_output.dat 2>&1
echo $?  # 결과: 0 (성공)
```

**검증 항목:**
- ✓ isatty() 체크 우회 성공
- ✓ 파이프 입력에서 정상 동작
- ✓ 리다이렉션 출력 정상 동작
- ✓ 오류 없이 ZMODEM 헤더 생성

### 전송 속도 측정 결과

| 프로토콜 | 파일 크기 | 전송 속도 (BPS) | 비고 |
|---------|---------|----------------|------|
| ZMODEM | 128 bytes | ~757 Kbps | 작은 파일 |
| ZMODEM | 1 KB | ~4.6 Mbps | 중간 파일 |
| ZMODEM | 10 KB | ~20.7 Mbps | 큰 파일 |
| YMODEM | 128 bytes | ~727 Kbps | 작은 파일 |
| YMODEM | 1 KB | ~4.3 Mbps | 중간 파일 |
| YMODEM | 10 KB | ~22.5 Mbps | 큰 파일 |
| XMODEM | 128 bytes | ~127 bps | 작은 파일, 느림 |
| XMODEM | 1 KB | ~1 Kbps | 블록 단위 전송 |
| XMODEM | 10 KB | ~10 Kbps | 80 블록 전송 |

**분석:**
- ZMODEM과 YMODEM은 유사한 성능을 보임
- XMODEM은 상대적으로 느린 전송 속도 (예상된 동작)
- 파일 크기가 클수록 전송 효율 향상

### 테스트 환경 상세

```bash
# 운영체제
Linux 6.8.0-85-generic

# socat 버전
socat version 1.8.0.0

# 바이너리 정보
./bin/lrz: ELF 64-bit LSB executable
./bin/lsz: ELF 64-bit LSB executable

# 패치 정보
PTY check removed in io_mode() function (src/rbsb.c)
```

### 결론

✓ **모든 프로토콜(XMODEM, YMODEM, ZMODEM) 정상 동작 확인**
✓ **TCP socket 연결을 통한 송수신 성공**
✓ **PTY 없는 환경에서 정상 동작 확인**
✓ **MD5 체크섬 검증 100% 통과**
✓ **telnet socket 연결 용도로 사용 가능**

---

**마지막 업데이트**: 2025-10-26
**테스트 환경**: Linux/Unix with socat
**lrzsz-lite 버전**: 0.12.20 (PTY-patched)
