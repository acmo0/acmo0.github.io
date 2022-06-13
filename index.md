
<head>
  <meta name="google-site-verification" content="GJ7maI25ulgEd4v2It-2FEokMZjFJyk5MacuSC0A2h8" />
</head>

# Android/Linux Youtube Downloader
## Table of Content
- [Android Version](#android)
  - [Features](#android-features)
  - [Download](#android-download)
  - [Description](#android-description)
    - [License](#android-license)
    - [Privacy](#android-privacy)
  - [About](#android-about)
- [Linux Version](#linux)
  - [Compatibility](#compatibility)
  - [Features](#features)
  - [Download](#download)
  - [Uninstallation](#uninstallation)
  - [Privacy](#privacy)
  - [License](#license)
## Android
### Android - Features

Download videos from various sites like :
- Youtube
- Twitter
- TikTok
- Dailymotion

([See the full list of available websites](https://ytdl-org.github.io/youtube-dl/supportedsites.html))

<img src="images/screen1.png" width="300" height="auto"/>    <img src="images/screen2.jpg" width="300" height="auto"/>

### Android - Download

[Download the lastest version from github](https://github.com/acmo0/Android-Youtube-Downloader/releases/latest).

Alternatively, you can build from source by downloading the source-code from github.

### Android -  Description

This application is a fully open-source project. The entire source code is available on [github](https://github.com/acmo0/Android-Youtube-Downloader).
#### License
This software is released under the [GPL-v3.0](https://github.com/acmo0/Android-Youtube-Downloader/blob/master/LICENSE). This software uses :
1. [Chaquopy](https://chaquo.com/chaquopy/) MIT License
2. [yt-dlp](https://github.com/yt-dlp/yt-dlp) The Unlicense
3. [pytube](https://github.com/pytube/pytube) The Unlicense
4. [ffmpeg-android-java](https://github.com/WritingMinds/ffmpeg-android-java) GPLv3.0

#### Android - Privacy

Android Youtube Downloader does not collect any user data. Some data are stored ONLY locally on your smartphone in order to improve your user experience.

## Android - About
See the [github repos](https://github.com/acmo0/Android-Youtube-Downloader) of the project.

See the [author github profile](https://github.com/acmo0).
***
## Linux

## Compatibility
Tested on ubuntu 20.04LTS and Kali linux. Should work on any debian-like distros.
[A version is also available for android](https://github.com/acmo0/Android-Youtube-Downloader).
## Features
- Search on youtube directly from the application
- Download videos and playlists in audio format (m4a, mp3, wav,flac,...)
## Download
### Using deb package
- [Download .deb file from lastest release](https://github.com/acmo0/youtube-downloader-linux/releases/latest)
- Install it using apt (assuming you are in the directory where is located your downloaded file)
```
sudo apt install ./youtube-downloader.deb
```
### Using tar archive
- [Download .tar.gz file from lastest release](https://github.com/acmo0/youtube-downloader-linux/releases/latest)
- Go where you have downloaded the archive and then type
```
tar -xvf youtube-downloader-<version number>.tar.gz
cd youtube-downloader
sudo make install
```
## Uninstallation
- If installed with apt, type ```sudo apt remove youtube-downloader```
- If installed with .tar.gz file, type ```sudo bash /usr/local/lib/youtube-downloader/uninstall```
## Privacy
This application does not collect any user data.
## License
This software is released under the [GPL-v3.0](https://github.com/acmo0/Android-Youtube-Downloader/blob/master/LICENSE). This software uses :
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) The Unlicense
- [youtube-search-python](https://github.com/alexmercerind/youtube-search-python) MIT License

***

See other projects of the author :
 - [GUI application for simple meteorological data analysis](https://github.com/acmo0/meteo)
 - [CTF write-ups](https://github.com/acmo0/write-ups)
 - [Description of an entire DIY pedalboard power supply](https://github.com/acmo0/PedalBoard-Power-Supply-Diy)
