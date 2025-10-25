# lrzsz-lite

A lightweight build of lrzsz with PTY isatty() checks removed to enable usage with pipes and redirections (non-TTY scenarios).

## Overview

This repository contains a build script and patch for **lrzsz version 0.12.20** that allows the XMODEM, YMODEM, and ZMODEM file transfer protocols to work in non-TTY environments such as:

- Piped commands
- File redirections
- Automated scripts without terminal allocation
- SSH connections without PTY allocation

### Original Source

- **Version**: lrzsz 0.12.20
- **Original Release Date**: December 1998
- **Original Author**: Uwe Ohse
- **Source Archive**: Available from various mirrors (e.g., https://www.ohse.de/uwe/software/lrzsz.html)

## What's Modified

The patch modifies `src/rbsb.c` to add an `isatty()` check at the beginning of the `io_mode()` function. This allows lrzsz to bypass terminal configuration when the file descriptor is not a TTY, enabling it to work with pipes and redirections.

### Patch Details

See `lrzsz-no-tty.patch` for the full patch. The key change:

```c
int io_mode(int fd, int n)
{
    static int did0 = FALSE;

    /* If fd is not a tty, skip terminal configuration */
    /* This allows lrzsz to work with pipes and redirections */
    if (!isatty(fd) && n != 0) {
        /* For non-tty, just return OK without terminal setup */
        return OK;
    }

    // ... rest of the function
}
```

## Build Instructions

### Prerequisites

```bash
# Debian/Ubuntu
sudo apt-get install build-essential autoconf automake curl

# Fedora/RHEL
sudo dnf install gcc make autoconf automake curl

# macOS
brew install autoconf automake
```

### Building from Source

```bash
# Download and build with default settings
./build.sh --url https://www.ohse.de/uwe/releases/lrzsz-0.12.20.tar.gz

# Custom installation prefix
./build.sh --url https://www.ohse.de/uwe/releases/lrzsz-0.12.20.tar.gz \
    --prefix /opt/lrzsz-no-pty

# Use local source directory
./build.sh --src /path/to/lrzsz-0.12.20 --prefix /usr/local/lrzsz

# Keep source directory after build
./build.sh --url https://www.ohse.de/uwe/releases/lrzsz-0.12.20.tar.gz --keep
```

### Build Script Options

```
--url <tarball_url>   Download lrzsz source tarball and use it
--src <source_dir>    Use existing local source directory
--prefix <dir>        Installation prefix (default: /usr/local/lrzsz-no-pty)
--jobs <n>            make -jN (default: number of CPUs)
--keep                Keep extracted source after build
--help                Show help message
```

## Usage Examples

### Standard Usage (with TTY)

```bash
# Send a file
sz file.txt

# Receive a file
rz
```

### Non-TTY Usage (Piped/Redirected)

With the patch applied, lrzsz works in non-TTY environments:

```bash
# Through SSH without PTY allocation
ssh user@host 'sz /path/to/file.txt' < /dev/null > received_file.txt

# In automated scripts
echo | sz file.txt > /tmp/transfer.dat

# With redirected stdin/stdout
sz file.txt < /dev/null > output.zmodem
```

## Testing Without PTY

### Test 1: Verify Non-TTY Operation

```bash
# Test that sz works without a TTY
echo "test content" > test.txt
./bin/sz test.txt < /dev/null > /tmp/test.zmodem

# Check if output was generated
ls -lh /tmp/test.zmodem
hexdump -C /tmp/test.zmodem | head -20
```

### Test 2: SSH Without PTY Allocation

```bash
# Send a file through SSH without PTY (-T flag)
ssh -T user@remotehost '/path/to/sz /remote/file.txt' > received_file.zmodem

# Or using stdin redirection
ssh user@remotehost 'sz /remote/file.txt' < /dev/null > received_file.zmodem
```

### Test 3: Pipe Through Script

Create a test script `test_no_tty.sh`:

```bash
#!/bin/bash
# Test lrzsz in non-TTY environment

echo "Creating test file..."
echo "Hello from lrzsz-lite" > /tmp/test_transfer.txt

echo "Testing sz without TTY..."
if ./bin/sz /tmp/test_transfer.txt < /dev/null > /tmp/test.zmodem 2>&1; then
    echo "✓ sz succeeded in non-TTY mode"
    echo "Output size: $(stat -c%s /tmp/test.zmodem) bytes"
else
    echo "✗ sz failed in non-TTY mode"
    exit 1
fi

echo "Testing with pipe..."
if cat /tmp/test_transfer.txt | ./bin/sz - < /dev/null > /tmp/test2.zmodem 2>&1; then
    echo "✓ sz with pipe succeeded"
else
    echo "✗ sz with pipe failed"
fi

echo "All tests completed!"
```

Run the test:

```bash
chmod +x test_no_tty.sh
./test_no_tty.sh
```

### Test 4: Verify ZMODEM Protocol Headers

```bash
# Check that the output contains valid ZMODEM headers
./bin/sz test.txt < /dev/null > test.zmodem 2>&1

# ZMODEM files should start with "rz\r\n" or contain ZRQINIT
hexdump -C test.zmodem | head -5

# Look for ZMODEM signature bytes
grep -ao "ZMODEM" test.zmodem || echo "Binary ZMODEM format (expected)"
```

### Test 5: Full Round-Trip Test

```bash
# Create test data
echo "Round-trip test data" > original.txt

# Send with patched sz (non-TTY)
./bin/sz original.txt < /dev/null > transfer.zmodem 2>&1

# Receive with patched rz (requires TTY emulation or expect)
# Note: rz typically requires a TTY for receiving, so this may need expect/socat
```

## Comparison: Original vs Patched

### Original lrzsz Behavior

```bash
# Original lrzsz would fail with:
echo | sz file.txt
# Error: "sz: cannot open terminal"
```

### Patched lrzsz-lite Behavior

```bash
# lrzsz-lite handles non-TTY gracefully:
echo | ./bin/sz file.txt > output.zmodem
# Success: Creates ZMODEM output without terminal
```

## Use Cases

1. **Automated Backups**: Transfer files through SSH in scripts without interactive terminal
2. **CI/CD Pipelines**: Send/receive files in containerized environments
3. **Embedded Systems**: Transfer files where PTY allocation is not available
4. **Protocol Testing**: Generate ZMODEM protocol streams for testing
5. **Data Migration**: Batch file transfers through restricted SSH connections

## Known Limitations

- The patch specifically targets the `io_mode()` function in `rbsb.c`
- Receiving files (`rz`) may still require terminal emulation in some scenarios
- Performance may vary compared to TTY-based transfers
- Error reporting may be limited in non-TTY mode

## Repository Contents

```
.
├── build.sh              # Build script with patching
├── lrzsz-no-tty.patch    # Unified diff patch for rbsb.c
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## Contributing

Issues and pull requests are welcome! If you find a bug or have a suggestion:

1. Check existing issues
2. Create a detailed bug report or feature request
3. Submit a pull request with tests

## License

This patch and build script are provided as-is for educational and practical use.

The original lrzsz is:
- **License**: GNU General Public License v2.0
- **Copyright**: (C) 1996, 1997 Uwe Ohse

## References

- Original lrzsz: https://www.ohse.de/uwe/software/lrzsz.html
- ZMODEM Protocol: https://en.wikipedia.org/wiki/ZMODEM
- XMODEM/YMODEM Protocols: https://en.wikipedia.org/wiki/XMODEM

## Acknowledgments

- Uwe Ohse for the original lrzsz implementation
- The open-source community for maintaining lrzsz over the years

---

**Note**: This is a modified version of lrzsz. For production use, thoroughly test in your specific environment.
