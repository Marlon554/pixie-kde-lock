# ✨ Pixie SDDM

A clean, modern, and minimal SDDM theme inspired by Google Pixel UI and Material Design 3. 

<div align="center">
  <img src="screenshots/lock_screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/login_screen.png" width="45%" alt="Login Screen" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_2.png" width="22%" />
  <img src="screenshots/login_screen_2.png" width="22%" />
  <img src="screenshots/lock_screen_3.png" width="22%" />
  <img src="screenshots/login_screen_3.png" width="22%" />
</div>

## 🌟 Features

- **Pixel Aesthetic:** Clean typography and a unique two-tone stacked clock.
- **Material You Dynamic Colors:** Intelligent color extraction that samples your wallpaper for UI accents.
- **Smooth Transitions:** High-performance fade-in animations for all UI elements.
- **Material Design 3:** Dark card UI with smooth interactions and responsive dropdowns.
- **Keyboard Navigation:** Full support for navigating menus with arrows and `Enter`.
- **Blur Effects:** Adaptive background blur that transitions smoothly when the login card is active.

---

## 📦 Prerequisites

Before installing, you **must** install the required Qt5 modules for your distribution to avoid a black screen:

<details>
<summary><b>Arch Linux / CachyOS / Manjaro</b> (Click to expand)</summary>

```bash
sudo pacman -S --needed qt5-graphicaleffects qt5-quickcontrols2 qt5-svg
```
</details>

<details>
<summary><b>Ubuntu / Debian / Mint / Kali</b> (Click to expand)</summary>

```bash
sudo apt update && sudo apt install qml-module-qtgraphicaleffects qml-module-qtquick-controls2 qml-module-qtquick-layouts libqt5svg5
```
</details>

<details>
<summary><b>Fedora / RHEL / CentOS</b> (Click to expand)</summary>

```bash
sudo dnf install qt5-qtgraphicaleffects qt5-qtquickcontrols2 qt5-qtsvg
```
</details>

<details>
<summary><b>openSUSE</b> (Click to expand)</summary>

```bash
sudo zypper install libqt5-qtgraphicaleffects libqt5-qtquickcontrols2 libqt5-qtsvg
```
</details>

---

## 🚀 Installation

### 1. Arch Linux (AUR)
Install the theme using your favorite AUR helper:
```bash
yay -S pixie-sddm-git
```

### 2. Automatic Script (Other Distros)
Recommended for most users. This script handles file copying and optional configuration:
```bash
git clone https://github.com/xCaptaiN09/pixie-sddm.git
cd pixie-sddm
sudo ./install.sh
```

### 3. NixOS (Declarative)
NixOS users should add the following snippet to their `/etc/nixos/configuration.nix`:

```nix
{ pkgs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";
  };

  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "pixie-sddm";
      src = pkgs.fetchFromGitHub {
        owner = "xCaptaiN09";
        repo = "pixie-sddm";
        rev = "main";
        sha256 = "sha256-0000000000000000000000000000000000000000000="; # Nix will prompt for the correct hash
      };
      installPhase = ''
        mkdir -p $out/share/sddm/themes/pixie
        cp -r * $out/share/sddm/themes/pixie/
      '';
    })
    pkgs.libsForQt5.qtgraphicaleffects
    pkgs.libsForQt5.qtquickcontrols2
    pkgs.libsForQt5.qtsvg
  ];
}
```

After editing, apply the configuration by running:
```bash
sudo nixos-rebuild switch
```

---

## 🛠 Configuration & Testing

### Apply Theme Manually
If you didn't use the script, set the theme in `/etc/sddm.conf.d/theme.conf`:
```ini
[Theme]
Current=pixie
```

### Test Without Logging Out
Run this command to preview the theme:
```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/pixie
```

---

## 🎨 Customization

Edit the `theme.conf` file inside the theme directory:
- **Wallpaper:** Replace `assets/background.jpg` with your own image.
- **Avatar:** Put your profile picture in `assets/avatar.jpg`.
- **Colors:** Adjust `accentColor` for manual overrides if needed.

## 🤝 Credits

- **Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design:** Inspired by Google Pixel and MD3.
- **Font:** Google Sans Flex (included).

---
*Made with ❤️ for the Linux community.*
