---
layout: post
title: Tu pointes ou tu tires 1/2 
subtitle: A challenge from StarHackademINT
tags: Write-up 2023 crypto arithmetic
---

## Énnoncé
A la fin d'une de vos traditionelles parti de boules du mardi avec les copaings, vous êtes interpellé par un duo qui vous a observé toute la partie:
"-Eh minot, tu joues pas mal! On cherche du monde pour notre créneau du samedi midi, tu serais intéressé?
-Pourquoi pas, j'ai rien de prévu le samedi
-Parfait ça! Mais y'a une particularité à nos sessions, on joue avec des vraies règles.
-C'est à dire?
-Vient demain soir, tu verras. Au fait, moi c'est Gégé, et lui c'est Pierrot. Et toi?"

*nc challenges.hackademint.org 30734*
## Solution
On a à disposition le fichier python qui est exécuté sur le server :
```python
from math import gcd

FLAG = ?

LIST_PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997]


def test_de_pierre(n):
    for p in LIST_PRIMES:
        if p >= n:
            return True
        if pow(p, n, n) != p:
            return False


if __name__ == '__main__':
    print("Gégé et Pierre vous regardent, au bord du terrain. Montrez leur votre niveau!")
    print("Le cochonet est en ligne de mire, seul. C'est le moment de bien viser!")
    while True:
        a = int(input('>'))
        b = int(input('>'))
        if a >= 1000:
            print(
                "La boule sort au delà des 15 mètres réglementaires. Gégé éclate de rire, son verre à la main:\n\"Ah, la fougue de la jeunesse! Vas-y minot, recommence.\"")
            continue
        if a <= 1:
            print(
                "La boule s'échappe de votre main et se plante à à peine 1 mètre.\n\"Bah alors gamin, t'as du savon sur les mains? Bois un pastis, ca te détendra!\" commente Gégé")
            continue

        if not test_de_pierre(a):
            print(
                "Alors que la boule s'envole, Pierre secoue la tête.\n\"L'angle d'éjection n'est pas bon, minot. Reprend ton coup, ici on joue avec des vraies règles!\"")
            continue

        g = gcd(a, b)
        if g == a or g == 1:
            print(
                "La boule s'envole, sans commentaires de la part de Pierre, tombe juste à côté du cochonet, mais continue rouler jusqu'à finir au delà des 15 mètres. \n\"Boule morte! Faut pas pointer aussi fort minot!\" Rigole Gégé, son verre à la main.")
            continue

        print(
            "Vous vous concentrez, lancez la boule avec précision. Elle atterit dans les limites, roule, et s'arrête sur le cochon. Gégé, impressioné, jette un coup d'oeil à Pierre: \n\"Rien à dire, le coup est valide.\"\nGégé vous regarde avec un air approbateur\n\"Bien joué gamin! Je savais que t'avais quelque chose de spécial. Je vais t'apprendre comment on joue vraiment à la pétanque.\"")
        print(FLAG)

```
Donc il faut que les deux entiers que l'on passe en paramètre remplissent les conditions suivantes : 
* `1 < a < 1000`
* `gcd(a,b) != a` et `gcd(a,b) != 1`
Et surtout `a` doit passer `test_de_pierre`
Vu l'intervalle dans lequel doit se situer `a` l'option la plus simple et de faire un brute-force pour trouver nos deux entiers:
```python
import math
def test_de_pierre(n):
    for p in LIST_PRIMES:
        if p >= n:
            return True
        if pow(p, n, n) != p:
            return False
LIST_PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997]
for i in range(1001):
    if test_de_pierre(i) and not i in LIST_PRIMES:
        print(i)
for i in range(1001):
    if math.gcd(i,561) != 561 and math.gcd(i,561) != 1:
        print(i)
        break
```
Output :
```
561
3
```
On se connecte au server avec netcat :
```
Gégé et Pierre vous regardent, au bord du terrain. Montrez leur votre niveau!
Le cochonet est en ligne de mire, seul. C'est le moment de bien viser!
>561
>3
Vous vous concentrez, lancez la boule avec précision. Elle atterit dans les limites, roule, et s'arrête sur le cochon. Gégé, impressioné, jette un coup d'oeil à Pierre: 
"Rien à dire, le coup est valide."
Gégé vous regarde avec un air approbateur
"Bien joué gamin! Je savais que t'avais quelque chose de spécial. Je vais t'apprendre comment on joue vraiment à la pétanque."
Star{P13RR3_D3_F3RM47_4PPR0UV3_C3_C0UP}
```