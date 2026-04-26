# ✨ Pixie KDE Lock

A clean, modern, and minimal kscreenlocker theme inspired by Google Pixel UI and Material Design 3. Pixie KDE Lock is a fork of Pixie SDDM by [xCaptaiN09](https://github.com/xCaptaiN09). It incorporates components from the KDE Plasma Lockscreen. This project is licensed under the GPL-v2.0-or-later, while original Pixie SDDM components remain under the MIT License.
<div align="center">
  <img src="screenshots/Lock Screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/Login Card.png" width="45%" alt="Login Screen" />
</div>

>[!CAUTION]
> **Warning:** This project modifies critical system files in `/usr/share/plasma`. Improper configuration can result in being locked out of your desktop session.
>
> After following the installations steps, do not log out, verify the QML logic with the greeter test tool:
>- **Arch Linux:** `/usr/lib/kscreenlocker_greet --testing`
>- **Fedora:** `/usr/lib64/kscreenlocker_greet --testing`
>- **Debian/Ubuntu:** `/usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet --testing`

---

## 🌟 Features

- **Pixel Aesthetic:** Clean typography and unique two-tone stacked clock
- **Material Design 3:** Dark card UI with smooth animations and press interactions
- **Circular Avatar:** Canvas-based circular profile picture
- **KDE Plasma Integration:** Native suspend, switch user, virtual keyboard and battery indicator

## 📦 Installation

**Follow the steps below to install:**
```bash
git clone https://github.com/Marlon554/pixie-kde-lock.git
cd pixie-kde-lock
chmod +x install.sh
./install.sh
```
---

>[!NOTE]
> During installation, the script automatically creates a backup of the original lock screen at:
`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen.bak`
>
> This allows you to restore the original configuration if needed.

## 🎨 Customization
Customization is managed by KDE Plasma. To change the background, simply right-click an image and set it as your lock screen wallpaper. Color extraction is currently unavailable.

## 🤝 Credits

- **[Pixie SDDM](https://github.com/xCaptaiN09/pixie-sddm) by xCaptaiN09:** original visual design, color palette, typography and animations. Licensed under MIT.
- **[KDE Plasma Lockscreen](https://invent.kde.org/plasma/plasma-workspace):** base QML structure and Plasma integration components. Licensed under GPL-2.0-or-later.
- **Design:** Inspired by Google Pixel and MD3.
- **Font:** Google Sans Flex (included).

---
*Made with ❤️ for the Linux community.*
