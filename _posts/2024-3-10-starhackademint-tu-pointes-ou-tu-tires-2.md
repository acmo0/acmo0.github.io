---
layout: post
title: Tu pointes ou tu tires 2/2
categories: Write-up 2023 cryptography arithmetic
---

## Énnoncé
A la fin de la session d'entrainement avec Gégé, celui-ci se retourne vers vous et vous dit:
"Allez minot, on passe aux choses sérieuses. Si tu arrives à bouger celle-là, je t'invite tous les samedi!"
*nc challenges.hackademint.org 30155*
## Solution
On a de nouveau accès au fichier python qui est exécuté par le server :
```python
from math import gcd
from Crypto.Util.number import getPrime

FLAG = ?


def nbits(n):
    return len(bin(n)[2:])


def test_de_pierre(n):
    for i in range(50):
        p = getPrime(nbits(n) - 1)
        if pow(p, n, n) != p:
            return False
    return True


if __name__ == '__main__':
    print("Gégé a extrêmement bien pointé. Il va falloir sortir le grand jeu pour déloger sa boule!")
    while True:
        a = int(input('>'))
        b = int(input('>'))
        if nbits(a) <= 2000:
            print(
                "La boule s'envole dans les airs, tape celle de Gégé, mais cette dernière ne bouge pas d'un millimètre.\n\"C'est pas avec ça que tu vas réussir, gamin. Plus fort!\"")
            continue

        if not test_de_pierre(a):
            print(
                "Alors que la boule s'envole, Pierre secoue la tête.\n\"L'angle d'éjection n'est pas bon, minot. Reprend ton coup, ici on joue avec des vraies règles!\"")
            continue

        g = gcd(a, b)
        if g == a or g == 1:
            print(
                "La boule s'envole, sans commentaires de la part de Pierre, mais rate celle de Gégé avant de rouler au-delà des 15 mètres \n\"Boule morte! T'as pas les yeux en face des trous, minot?\" Rigole Gégé, son verre à la main.")
            continue

        if nbits(b) <= 500:
            print("La boule de s'envole, tape celle de Gégé, et les deux partent dans la zone morte.\n\"C'est pas mal minot, mais c'est pas un carreau. Je suis sûr que tu peux mieux faire!\"")
            continue

        print(
            "Vous vous concentrez, lancez la boule avec une belle hauteur. Elle atterrit sur celle de Gégé, et prend sa place en l'envoyant valser en dehors du terrain.\n Pierre pousse un sifflement, impressioné.\n\"C'est superbe minot! Je savais que j'avais raison de te faire confiance.\"")
        print(FLAG)
```
Le principe des conditions est le même que pour la première partie du challenge mais `a` et `b` sont bien plus grands, il est inutile d'effectuer un brute-force pour les déterminer.
On a par contre un indice en lisant le flag de la première partie : `P13RR3_D3_F3RM47_4PPR0UV3_C3_C0UP`.
En se renseignant sur des tests proposés par Pierre de Fermat on se rend compte qu'il a mis au point un test de [pseudo-primalité](https://fr.wikipedia.org/wiki/Test_de_primalit%C3%A9_de_Fermat). Cependant, il existe une famille de nombres qui valide le test de Fermat sans pour autant être premiers : [les nombres de Carmichael](https://fr.wikipedia.org/wiki/Nombre_de_Carmichael).
Il faut donc réussir à fabriquer un nombre de Carmichael qui fasse plus de 2000bits et donc un des facteurs fait au moins 501bits. Il existe une expression pour trouver certains nombres de Carmichael qui conviennent parfaitement :
```python
c = (6*k+1)*(12*k+1)*(18*k+1)
```
*c* est un nombre de Carmichael si *(6k+1), (12k+1)* et *(18k+1)* sont premiers.
Pour que *c* fasse au moins 2000bits il faut que *k* fasse au moins 667bits.
En utilisant l'indice fourni par l'énnoncé pour la modeste somme de quelques dizaines de points en moins on nous donne la valeur de *k* à partir de laquelle commencer le brute-force : `k=10^201 + 500000` (pas forcément nécessaire de le savoir mais ça permet de diminuer le temps passé à brute-force)
Le script suivant permet de trouver la bonne valeur de *k* :
```python
from Cryptodome.Util.number import isPrime

def nbits(n):
    return len(bin(n)[2:])

def C(k):
    n=(6*k+1)*(12*k+1)*(18*k+1)
    return n
 
def findCar(k_0):
    find = False
    k_it = k_0
    while not find:
        f3 = 0
        f2 = 0
        f1 = 6*k_it+1
        if not isPrime(f1):
            k_it+=1
            continue
        f2 = 12*k_it+1
        if not isPrime(f2):
            k_it+=1
            continue
        f3 = 18*k_it+1
        if isPrime(f3):
            print("[+] Find :\nk=",k_it,"\nC=",f1*f2*f3)
            break
        k_it+=1

k=10**201 + 500000
findCar(k)
```
Au bout de quelques minutes :
```
[+] Find :
k= 1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000772731 
C= 1296000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003004378524000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002321576727230556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000597984847488825652009
```
En se connectant avec netcat au server puis en lui donnant les deux nombres trouvés (*C* et *6k+1*) on obtient le flag !