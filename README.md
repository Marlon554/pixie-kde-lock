# Pixie KDE Lock

A clean, modern, and minimal kscreenlocker theme inspired by Google Pixel UI and Material Design 3.
<div align="center">
  <img src="screenshots/Lock_Screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/Login_Card.png" width="45%" alt="Login Screen" />
</div>

> [!CAUTION]
> This project modifies critical components in `/usr/share/plasma`. I am not responsible for any broken systems. **USE AT YOUR OWN RISK**. When installing, please test using the command `/usr/lib/kscreenlocker_greet --testing`, `/usr/lib64/kscreenlocker_greet --testing` or `/usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet --testing`, depending on your distribution.

---

## Features

- **Pixel Aesthetic:** Clean typography and a unique two-tone stacked clock.
- ~~**Material You Dynamic Colors:** Intelligent color extraction that samples your wallpaper for UI accents.~~
- ~~**Next-Gen Blur:** High-performance Gaussian blur (Qt6) and custom shader blur (Qt5).~~
- ~~**Universal Circle Avatar:** A bulletproof, anti-aliased circular profile mask that works on all systems.~~
- **Material Design 3:** Dark card UI with smooth interactions and responsive dropdowns.
- ~~**Keyboard Navigation:** Full support for navigating menus with arrows and `Enter`.~~

## Installation

**To install it:**
```bash
git clone https://github.com/Marlon554/pixie-kde-lock.git pixie-kde-lock
cd pixie-kde-lock
chmod +x install.sh
./install.sh
```
> [!NOTE]
> During installation, the script automatically creates a backup of the original lockscreen folder located in `/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen`. This ensures you can restore it if needed.

## Customization
Customization is handled by KDE Plasma. You can change the background by right-clicking on an image and setting it as your lock screen wallpaper (color extraction is currently unavailable).

## 🤝 Credits

- **Pixie KDE Lock Author:** [Marlon554](https://github.com/Marlon554)
- **Pixie SDDM Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design:** Inspired by Google Pixel and MD3.
- **Font:** Google Sans Flex (included).

---
*Made with ❤️ for the Linux community.*
