---
layout: post
title: Interpolation
tags: Write-up 2024 crypto HeroCTF
---
# Description
> Has missing data really ever stopped anyone ?

> [link of the challenge](https://github.com/HeroCTF/HeroCTF_v6/tree/2908eb81a8677da569a6a6b0007de8afcda3de20/Crypto/Interpolation)
> Author : Alol

# File
```python
#!/usr/bin/sage
import hashlib
import re

with open("flag.txt", "rb") as f:
    FLAG = f.read()
    assert re.match(rb"Hero{[0-9a-zA-Z_]{90}}", FLAG)

F = FiniteField(2**256 - 189)
R = PolynomialRing(F, "x")
H = lambda n: int(hashlib.sha256(n).hexdigest(), 16)
C = lambda x: [H(x[i : i + 4]) for i in range(0, len(FLAG), 4)]

f = R(C(FLAG))

points = []
for _ in range(f.degree()):
    r = F.random_element()
    points.append([r, f(r)])
print(points)

flag = input(">").encode().ljust(len(FLAG))

g = R(C(flag))

for p in points:
    if g(p[0]) != p[1]:
        print("Wrong flag!")
        break
else:
    print("Congrats!")
```

# Solution
We have a polynomial interpolation problem over the field $F_{2^{256} - 189}$. The coefficient of the polynomial are made by taking the sha256 of each 4-characters blocks of the flag. Because we have the flag format (`Hero{[0-9a-zA-Z_]{90}}`), we can deduce that the polynomial will be of degree `96/4 - 1 = 23`. However the algorithm only outputs 23 differents random points, we are missing 1 point to be able to use Lagrange's interpolation. 

Nonetheless, we also have the information that $f(0) = sha256('Hero')$ thanks to the flag format and because the field is big enough, we can assume that we will never get $f(0)$ as an outputed point : we have our 24 differents points and we are now able to recover the polynomial !

Given the list of the points : `points = [(x0, f(x0)), (x1, f(x1)), ... ]`, we can compute the coefficients :
```python
#!/usr/bin/sage
F = FiniteField(2**256 - 189)
R = PolynomialRing(F, "x")

print(list(R.lagrange_polynomial(points)))
```
Then we convert the points to hex values and put them in a text file :
```
72a9345fb29494a4e9667d7bd68f37e8fe1df384270553f17b4c4a06b1f2b5e0
52a59ed59e4591d6e82565fb77798383369dc28b9c49445520fb55eddbeba47e
796d0f80fb1e4f3c2a7e2324934ef87acede62e2509ca1f90d966c6d40371cde
ad01855e9902b239d80f2df128f5a400b0b44a67370ec65d2f5ddfe2357bffe8
5eb00a6ae5252541478db75b71b0c30f47b7253401f7069dd8e25edd28af1f31
24b668d65947b851ff15f94eada6889bb8717de6a08a163efde5033f4704790d
16214760387ea9000e725837bd3c82a66b601d8a5b58cf70247bf82779a195db
ade00d675dae2ebd5fd3d512451f1f18fee89ca6dc74c877b50f53143c73a3b5
9622bb1b240004c991ac10b614c5494abb23ee04e8537914b8afce806cd8e14
a24544a4e68294f11dc703524df912f2f3c0e79787008f9301e63887464202f
da28dfe3d94cfe559962cacda8e9c2b3e607c16267f652ab48a51a686ce2769a
227b376e42907c00df3e83d0947f9e0d577b2d168ae72ab69311a33c43c4b8cf
47a3f653e3fb9bf47cbcd30aaae7b717c1af23a1ba8e93642c0670b25eccb27c
ff6dd5e8dd7482fa067fcd3c571982eae5251c2772ea4ad323624dba9b5c4b9a
fae2767a3fc77a76dcfaca2c1c9d320915d695bcf53b2ce042ef215f33d9a97
936c5ba388ba372bafe66f94cd35a9e1180005168fec3dc32b07a707b0f385ba
6061caf04054c64b716d907ba0d2d86b9c737f54aec9e495d65e636f11e74f9f
cb0cc21de33d1a39bd3a0ab6339b1a17652f37c8716f0dd8be78292847369220
e936285de2a9126f5dcb1bba1a7622d227fdb59a05242de6a8822c87711ce751
6b2dd21f6a189e2a51f0211d149604e3c48d6249eb6ad2f573a5a962a06793c6
1487fe4eeb54f8eac2064095d592b3752a9f8f9e1d65ce066d035f0cf4c33eab
9d5d4595e5f95f0ee55a8f4d1c55a2fc91460e31bf353f7c0cc2934646511e11
81c07fe97073967e5dd7345b129255c26a5d7b0de04bf3025d44bdd2f8ee4145
c9f9e4e09a1e05e83b35c9be80af5ed4d4c1df1a3186b2639532e3d6bac153cd
```
Then, I used hashcat to crack all those hashes -and create a special charset for bruteforcing because we have the regex of the flag format- : `hashcat -a 3 -m 1400 hash.txt --custom-charset1='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{}_' ?1?1?1?1 -o ./cracked.txt`

Then, by taking in the right order the recovered sha256 hashes, we have the flag : `Hero{th3r3_4r3_tw0_typ35_0f_p30pl3_1n_th15_w0rld_th053_wh0_c4n_3xtr4p0l4t3_fr0m_1nc0mpl3t3_d474}`
***
*Write-up author : acmo0