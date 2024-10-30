---
layout: post
title: Xorrible 
tags: Write-up 2023 cryptography
---

## Énnoncé
Vous avez trouvé un message pipou chiffré en xor. Nos meilleurs analystes de MiNET nous disent que le mesage est beacoup trop long, et que le bruteforcer casseait la connexion intenet. Voulant déchiffrer ce message pipou comme tout ET permettre à Raphaël Bachelier de continer à passer ses nuits sur League of Legends, vous vous proposez de déchiffrer ce message :

00111111 11101111 10001111 00011001 11011110 00101001 11110101 10111000 00011001 11000100 00000101 11010111 10001011 00110011 11001010 00011110 11011000 10001011 00011000 11010001 00101111 11110100 10000001 00000111 11011000

Bonne chance
## Solution
Pour retrouver la clé utilisée pour chiffrer ce message on va effectuer une attaque par clair connu.
Le principe est le suivant : on connaît le début du message qui est "Star{", on va donc calculer assez facilement la clé utilisée (en espérant qu'elle ne fasse pas plus de 5 octets, ce qui est fort probable)
On converti les données binaires vers des bytes pour faciliter le calcul avec python.
Il est intéressant de noter que si l'on note *^* l'opérateur XOR, *c* le message chiffré, *k* la clé et *m* le message en clair alors on a :
`c = k^m` et `k = c^m`
On fait un script python pour exécuter l'attaque :
```python3
c = b'\x3f\xef\x8f\x19\xde\x29\xf5\xb8\x19\xc4\x05\xd7\x8b\x33\xca\x1e\xd8\x8b\x18\xd1\x2f\xf4\x81\x07\xd8'
k = b''
m = b'Star{'
def byte_xor(ba1, ba2):
    return bytes([_a ^ _b for _a, _b in zip(ba1, ba2)])

k = byte_xor(c[:len(m)],m)
#On répète notre clé pour qu'elle fasse la même taille que le message chiffré
key = k*(len(c)//len(k))+k[:len(c)%len(k)]
print(byte_xor(c,key))
```
Ouput :
```
Star{EnVraiLeXorCestCool}
```