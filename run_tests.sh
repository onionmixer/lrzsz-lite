#!/bin/bash

# lrzsz-lite Test Script for Socket Transfer
# Tests XMODEM, YMODEM, and ZMODEM protocols over TCP sockets

set +e  # Continue on error

# Configuration
WORKSPACE="/mnt/USERS/onion/DATA_ORIGN/Workspace/lrzsz-lite"
LRZSZ_BIN="$WORKSPACE/bin"
TEST_DIR="$WORKSPACE/test_area"
SEND_DIR="$TEST_DIR/send"
RECV_DIR="$TEST_DIR/recv"
PORT=12345

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
PASS_COUNT=0
FAIL_COUNT=0

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

print_test() {
    echo ""
    echo ">>> Test: $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

print_info() {
    echo -e "${YELLOW}INFO${NC}: $1"
}

# Cleanup function
cleanup() {
    pkill -f "socat.*$PORT" 2>/dev/null || true
    sleep 1
}

# Test function: protocol filename
test_transfer() {
    local protocol=$1
    local filename=$2
    local test_name="$protocol - $filename"

    print_test "$test_name"

    # Skip empty files for XMODEM
    if [ "$protocol" = "xmodem" ] && [ "$filename" = "test_empty.bin" ]; then
        print_info "Skipping empty file for XMODEM (not supported)"
        return 0
    fi

    # Clean receive directory
    rm -f "$RECV_DIR"/*

    # Set protocol options
    local rx_opts=""
    local sx_opts=""
    case $protocol in
        xmodem)
            rx_opts="-X"
            sx_opts="-X"
            ;;
        ymodem)
            rx_opts="-y"
            sx_opts="-y"
            ;;
        zmodem)
            # Default, no special flags needed
            ;;
    esac

    # Get original checksum
    local original_md5=$(md5sum "$SEND_DIR/$filename" | awk '{print $1}')
    print_info "Original MD5: $original_md5"

    # Start receiver in background
    cd "$RECV_DIR"
    if [ "$protocol" = "xmodem" ]; then
        # XMODEM needs explicit filename
        socat TCP-LISTEN:$PORT,reuseaddr SYSTEM:"$LRZSZ_BIN/lrz $rx_opts $filename" &
    else
        socat TCP-LISTEN:$PORT,reuseaddr SYSTEM:"$LRZSZ_BIN/lrz $rx_opts" &
    fi
    local receiver_pid=$!

    # Wait for receiver to start
    sleep 2

    # Send file
    cd "$SEND_DIR"
    timeout 10 socat TCP:localhost:$PORT SYSTEM:"$LRZSZ_BIN/lsz $sx_opts $filename" 2>&1 || true

    # Wait for transfer to complete
    sleep 2

    # Kill receiver
    kill $receiver_pid 2>/dev/null || true
    wait $receiver_pid 2>/dev/null || true

    # Verify file was received
    if [ ! -f "$RECV_DIR/$filename" ]; then
        print_fail "File not received"
        return 1
    fi

    # Verify checksum
    local received_md5=$(md5sum "$RECV_DIR/$filename" | awk '{print $1}')
    print_info "Received MD5: $received_md5"

    if [ "$original_md5" = "$received_md5" ]; then
        print_pass "Checksum match"
        return 0
    else
        print_fail "Checksum mismatch!"
        return 1
    fi
}

# Main test execution
main() {
    print_header "lrzsz-lite Socket Transfer Tests"

    echo "Workspace: $WORKSPACE"
    echo "Test Directory: $TEST_DIR"
    echo "Port: $PORT"

    # Check binaries exist
    if [ ! -f "$LRZSZ_BIN/lrz" ] || [ ! -f "$LRZSZ_BIN/lsz" ]; then
        echo "Error: lrzsz binaries not found in $LRZSZ_BIN"
        exit 1
    fi

    # Check test files exist
    if [ ! -d "$SEND_DIR" ] || [ -z "$(ls -A $SEND_DIR 2>/dev/null)" ]; then
        echo "Error: No test files found in $SEND_DIR"
        exit 1
    fi

    print_info "Available test files:"
    ls -lh "$SEND_DIR"

    # Cleanup any existing socat processes
    cleanup

    # ZMODEM Tests
    print_header "ZMODEM Protocol Tests"
    test_transfer "zmodem" "test_text.txt"
    cleanup
    test_transfer "zmodem" "test_128.bin"
    cleanup
    test_transfer "zmodem" "test_1K.bin"
    cleanup
    test_transfer "zmodem" "test_10K.bin"
    cleanup

    # YMODEM Tests
    print_header "YMODEM Protocol Tests"
    test_transfer "ymodem" "test_text.txt"
    cleanup
    test_transfer "ymodem" "test_128.bin"
    cleanup
    test_transfer "ymodem" "test_1K.bin"
    cleanup
    test_transfer "ymodem" "test_10K.bin"
    cleanup

    # XMODEM Tests
    print_header "XMODEM Protocol Tests"
    test_transfer "xmodem" "test_empty.bin"  # Will be skipped
    cleanup
    test_transfer "xmodem" "test_128.bin"
    cleanup
    test_transfer "xmodem" "test_1K.bin"
    cleanup
    test_transfer "xmodem" "test_10K.bin"
    cleanup

    # Final report
    print_header "Test Summary"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo "Total: $((PASS_COUNT + FAIL_COUNT))"

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main
main
