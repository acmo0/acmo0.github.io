---
layout: post
title: Lazy Sysadmin 2
subtitle: A challenge from HeroCTF
tags: Write-up 2024 forensic HeroCTF
---
# Description
> You have identified the malicious load, it seems, that a script was executed before the computer turns off, you made a copy of the disk and you start investigating to understand the "extent of the damage"

> [link of the challenge](https://github.com/HeroCTF/HeroCTF_v6/tree/2908eb81a8677da569a6a6b0007de8afcda3de20/Forensics/LazySysAdmin2)
> Author : Mallon

> File : [challenge.zip](https://mega.nz/file/TNp11ZTb#yuC0rnLYZIMkcdElRXFQvbCzKjnIUZH7JRjaM4g4NZQ)

# Solution
To start, I first unzipped the file and uncompress the ISO to got the filesystem. I tried to find something relevant in the bash history of the user and the root user but I didn't find anythin. I also looked at the cache, the ssh authorized keys, ...
Then I looked at the `/tmp` and found a suspicious file named `.script.sh` in this dir :
```bash
#!/bin/bash

# get a random number
RANDOM_NUMBER=$(shuf -i 1-13 -n 1)

# retrieve content remotly from a pastebin
INSUTLS=$(curl -s https://pastebin.com/raw/59mL2V9i)

#select the n-th line (n being chosen randomly)
temp=$(echo "$INSUTLS" | sed -n "${RANDOM_NUMBER}p" )

#decode the content base64-encoded
tempp= echo "$temp" | base64 -id

# display to all terminal the content
wall $tempp
```

So I executed `curl -s https://pastebin.com/raw/59mL2V9i` and got some base64 encoded content. By decoding it, I got the flag : `HERO{AlwaYs-Ch3ck_What_u-C0Py-P4ste}`
