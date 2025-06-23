# UmmIt Packages

This repository contains various packages for UmmItOS with Arch Linux PKGBUILD powered.

## Directory Structure

```
packages/
├── core-packages/     # Core system packages (empty for now)
├── pen-packages/      # Penetration testing and security tools
│   └── ....
└── ....
```

## Package Categories

### core-packages/

Core system packages and essential utilities. Currently empty but reserved for future core system packages, such as UmmIt-settings or others, but not finished yet.

### pen-packages/

Penetration testing, security, and forensics tools. This category includes tools used for:

- Password cracking and brute-forcing
- Network security testing  
- Digital forensics
- Security analysis

Packages are usually not included in the official AUR, so we build our own packages.

## Usage

To build a package as an example:

```bash
git clone https://github.com/UmmItOS/packages
cd pen-packages/bruteforce-luks
makepkg -si
```