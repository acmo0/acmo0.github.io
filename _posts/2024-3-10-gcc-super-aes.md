---
layout: post
title: Super AES 
subtitle: A challenge from GCC CTF
tags: Write-up 2024 crypto lcg symetric GCC
---

## Description

Come try my super AES encryptor.

> 28 solves

## Author
[Shadowwws](https://twitter.com/Shadowwws7)
## Résolution
Nous avons à disposition un "oracle" de chiffrement dont le code nous est donnée :

```python
import random
from Cryptodome.Cipher import AES
import time
import os
from flag import flag

m = 288493873028852398739253829029106548736

a = int(time.time())

b = a%16

s = random.randint(1,m-1)

class LCG:
    def __init__(self, a, b, m, seed):
        self.a = a
        self.b = b
        self.m = m
        self.state = seed
        self.counter = 0
    def next_state(self):
        ret = self.state
        self.state = (self.a * self.state + self.b) % self.m
        return ret

class SuperAES:
    def __init__(self,key,lcg):
        self.aes = AES.new(key,AES.MODE_ECB)
        self.lcg = lcg

    def encrypt(self,plaintext):
        ciphertext = b""
        for i in range(0,len(plaintext),16):
            ciphertext += self.encrypt_block(plaintext[i:i+16])

        return ciphertext

    def encrypt_block(self,block):
        keystream = self.aes.encrypt(int(self.lcg.next_state()).to_bytes(16,"big"))
        return bytes([k^b for k,b in zip(keystream,block)])

assert len(flag) == 33
assert flag.startswith(b"GCC{") 

key = os.urandom(32)

cipher = SuperAES(key,LCG(a,b,m,s))

times = int(input("how many times do you want the flag ?"))

assert times < 50

print(cipher.encrypt(flag*times).hex())
```
En analysant un petit peu ce code, on comprend notamment que le chiffrement AES est en mode ECB (ce qui va avoir son importance pour la suite) et que le chiffremenet AES est utilisé pour générer un bloc qui va être xoré avec le flag. De plus, ce qui génère le flot d'octets avant l'AES est un [lcg](https://en.wikipedia.org/wiki/Linear_congruential_generator) dont on connaît le modulo, dont le coefficient *a* est juste la date en seconde et la coefficent *b = a [16]*. Ce qui est intéressant est que *b* ne prend que 16 valeurs distinctes. Une autre information primordiale est que l'on peut demander le chiffrement du flag concaténé avec lui-même jusqu'à 49 fois.

Quelle est la faiblesse de ce cryptosystème ?

Le LCG génére des blocs de 16 octets, puisqu'il est à la base de la clé qui chiffre notre flag, il est fort probable que ce soit le composant le plus vulnérable. Si jamais on arrive à obtenir des coefficients *a* et *b* tels que le LCG a une période très petite, alors on pourra être capable de déchiffrer le flag. Avant de faire des maths, on peut toujours essayer d'afficher quelques suites d'octets générés par notre LCG.
Et là,... bingo pour certaines valeurs de *a* et *b* le LCG tombe dans un point fixe, c'est à dire que considérant un état *s* du LCG à un instant t, on a : *as+b [m] = s*.

C'est là qu'intervient le fait que AES soit utilisé en mode [ECB](https://fr.wikipedia.org/wiki/Mode_d%27op%C3%A9ration_(cryptographie)#%C2%AB_Electronic_Codebook_Block_%C2%BB_(ECB):_dictionnaire_de_codes), le chiffrement d'un même bloc donnera toujours le même chiffré (contrairement au mode [CBC](https://fr.wikipedia.org/wiki/Mode_d%27op%C3%A9ration_(cryptographie)#%C2%AB_Cipher_Block_Chaining_%C2%BB_(CBC):_encha%C3%AEnement_de_blocs) par exemple).
Enfin, le dernier élément qui va nous permettre de récupérer le flag est le flag lui-même, on connait sa taille (33 octets) et on sait qu'il commence par "GCC{", autrement dit on connaît ses 4 premiers octets.
Il est temps de demander au serveur quelques chiffrés, on va lui demander de chiffrer la longueur maximale possible, 49 fois le flag donc (qui peut le plus peut le moins). On lui demande des chiffrés une fois toutes les secondes afin d'avoir des valeurs de *a* et *b* différentes.
Maintenant que l'on a ça, comment détecter lorsque le LCG est tombé sur un point fixe ?
On procède de la manière suivante :
- Pour chaque chiffré :
	- Découper le chiffré en blocs de 32 caractères ( donc 16 octets, la taille du bloc AES )
	- Si dans un chiffré on trouve deux lignes identiques, il est fort probable que le LCG soit tombé sur un point fixe, le texte est un "bon" chiffré

Si le texte est un bon chiffré alors chaque bloc de 16 octets est chiffré avec la même clé. Voici un exemple :
<details>
  <summary>Afficher l'exemple</summary>
  ### Exemple de chiffré faible
  ```
  68e0e53340f42e2d55c76666cd68404e
	ce348ce07b77c4f6b5b67b4a5b288a64
	9a8e6c59a848c208f00ab18963a8a1ac
	de5e475677ea61901ff27ffe298148f7
	fe0c228a9d4784fcab6b37bccebfe566
	386306e76520c9be2b805e68f934b0b3
	fb370e82224d2bb7aea9e294cba77ec0
	c79d91266096f39742b64b08792dcc61
	c6d485d3bf7ff405c454beed7319870a
	b70a7353289c7f18f7e2cf872ec7c9a9
	45003b26952a27cef1d3a22736264664
	b07147d75c39cd838fb4f812a78e6214
	57cb316fe1f19e1e8f925ae602c41ab1
	717f36619f87d701166530519cf4dc5d
	3372133432e3a22384877705826845eb
	7d650bd055f4bc7dd972ccef0d82a88c
	0b98966cf62537bce44515d4c4885a15
	fe75d65e1ef56fb787b5434bcd476034
	f77ad55e45b42ddd9bad6767d9534d37
	ef7edc6528e8689bb98b7b43cd4c5b0d
	fd77d36628b329d9d3976367e1584f20
	fe6fd76f13de759c95b5457bc54c5036
	c47dde6010de2eddd7df5963e1604422
	e97ec66419e5438192997b45fd44503d
	ff44d46d16e643dad3db1159e5607c29
	eb69d77512ef78b78f9e577bc37c583d
	f47fed671be07bb7d4df1511df647c11
	e06bc06403e4728cb9835057fd426035
	f474d65e11ed7d8fb9d81115975e7811
	d860c27312f5798682b54d50d17c5e0d
	fc74dd6528e7708981b5161193164215
	d858c97105e4688d888e7b4dd6506033
	c47cdd6e13de7a84878d7b1697120a2f
	dc58f17a07f3799c8384407bcb574c0d
	fa44d56e18e5438e8a8b437b90160e67
	e65cf1420cf16e8d928f4a40fd4a4b21
	c47aed6618ee78b780864543fd110a63
	ae66f54234fa6c9a839e414ac67c5626
	e844d35e10ee738cb98c4845c57c0d67
	aa2ecf4634c26798948f5041cc47603b
	ef68ed6028e6738782b54248c3446060
	ae2a877c30c25f9396984150c74d5b0d
	f26fc15e16de7b87898e7b42ce42580d
	a92e83340ac65fab9d9a5641d6465136
	c472c67228e0438f8985407bc44f5e35
	c429873042fc5baba5915456c7575a3c
	ff44db7504de7db781854b40fd455333
	fc44803446b461afa5a95f54d0464b37
	f57fed6803f24389b98d4b4bc67c593e
	fa7ced3342b02995a1a9675fd2515a26
	fe75d65e1ef56fb787b5434bcd476034
	f77ad55e45b42ddd9bad6767d9534d37
	ef7edc6528e8689bb98b7b43cd4c5b0d
	fd77d36628b329d9d3976367e1584f20
	fe6fd76f13de759c95b5457bc54c5036
	c47dde6010de2eddd7df5963e1604422
	e97ec66419e5438192997b45fd44503d
	ff44d46d16e643dad3db1159e5607c29
	eb69d77512ef78b78f9e577bc37c583d
	f47fed671be07bb7d4df1511df647c11
	e06bc06403e4728cb9835057fd426035
	f474d65e11ed7d8fb9d81115975e7811
	d860c27312f5798682b54d50d17c5e0d
	fc74dd6528e7708981b5161193164215
	d858c97105e4688d888e7b4dd6506033
	c47cdd6e13de7a84878d7b1697120a2f
	dc58f17a07f3799c8384407bcb574c0d
	fa44d56e18e5438e8a8b437b90160e67
	e65cf1420cf16e8d928f4a40fd4a4b21
	c47aed6618ee78b780864543fd110a63
	ae66f54234fa6c9a839e414ac67c5626
	e844d35e10ee738cb98c4845c57c0d67
	aa2ecf4634c26798948f5041cc47603b
	ef68ed6028e6738782b54248c3446060
	ae2a877c30c25f9396984150c74d5b0d
	f26fc15e16de7b87898e7b42ce42580d
	a92e83340ac65fab9d9a5641d6465136
	c472c67228e0438f8985407bc44f5e35
	c429873042fc5baba5915456c7575a3c
	ff44db7504de7db781854b40fd455333
	fc44803446b461afa5a95f54d0464b37
	f57fed6803f24389b98d4b4bc67c593e
	fa7ced3342b02995a1a9675fd2515a26
	fe75d65e1ef56fb787b5434bcd476034
	f77ad55e45b42ddd9bad6767d9534d37
	ef7edc6528e8689bb98b7b43cd4c5b0d
	fd77d36628b329d9d3976367e1584f20
	fe6fd76f13de759c95b5457bc54c5036
	c47dde6010de2eddd7df5963e1604422
	e97ec66419e5438192997b45fd44503d
	ff44d46d16e643dad3db1159e5607c29
	eb69d77512ef78b78f9e577bc37c583d
	f47fed671be07bb7d4df1511df647c11
	e06bc06403e4728cb9835057fd426035
	f474d65e11ed7d8fb9d81115975e7811
	d860c27312f5798682b54d50d17c5e0d
	fc74dd6528e7708981b5161193164215
	d858c97105e4688d888e7b4dd6506033
	c47cdd6e13de7a84878d7b1697120a2f
	dc58f17a07f3799c8384407bcb574c0d
	fa44d56e18e5438e8a8b437b90160e67
	e6
  ```
</details>

On voit que le bloc `dc58f17a07f3799c8384407bcb574c0d` est répété 3 fois. Pour déchiffrer cela, on effectue en fait une attaque à clair connu, le flag fait exactement 33 caractères et on connaît les 4 premiers. Ainsi, un flag va prendre deux blocs de clé pour le chiffrement, plus un octet, ce qui va induire un décalage. C'est ce décalage qui va nous permettre de récupérer la clé en connaissant les 4 premiers octets du flag.
En considérant le bloc suivant :
</details>
```
	dc58f17a07f3799c8384407bcb574c0d
	fa44d56e18e5438e8a8b437b90160e67
	e65cf1420cf16e8d928f4a40fd4a4b21
	c47aed6618ee78b780864543fd110a63
	ae66f54234fa6c9a839e414ac67c5626
	e844d35e10ee738cb98c4845c57c0d67
	aa2ecf4634c26798948f5041cc47603b
	ef68ed6028e6738782b54248c3446060
	ae2a877c30c25f9396984150c74d5b0d
	f26fc15e16de7b87898e7b42ce42580d
	a92e83340ac65fab9d9a5641d6465136
	c472c67228e0438f8985407bc44f5e35
	c429873042fc5baba5915456c7575a3c
	ff44db7504de7db781854b40fd455333
	fc44803446b461afa5a95f54d0464b37
	f57fed6803f24389b98d4b4bc67c593e
	fa7ced3342b02995a1a9675fd2515a26
	fe75d65e1ef56fb787b5434bcd476034
	f77ad55e45b42ddd9bad6767d9534d37
	ef7edc6528e8689bb98b7b43cd4c5b0d
	fd77d36628b329d9d3976367e1584f20
	fe6fd76f13de759c95b5457bc54c5036
	c47dde6010de2eddd7df5963e1604422
	e97ec66419e5438192997b45fd44503d
	ff44d46d16e643dad3db1159e5607c29
	eb69d77512ef78b78f9e577bc37c583d
	f47fed671be07bb7d4df1511df647c11
	e06bc06403e4728cb9835057fd426035
	f474d65e11ed7d8fb9d81115975e7811
	d860c27312f5798682b54d50d17c5e0d
	fc74dd6528e7708981b5161193164215
	d858c97105e4688d888e7b4dd6506033
	c47cdd6e13de7a84878d7b1697120a2f
```
</details>
On peut mettre en relation les clairs et chiffrés connus :
```
chiffré : dc 58 f1 7a 07f3799c8384407bcb574c0d
clair :   G  C  C  {  ?
clé :     9b 1b b2 01 ?
```
Ensuite, huit lignes plus loin, on a :
```
chiffré : ae2a877c 30 c2 5f 93 96984150c74d5b0d
clair :   ?        G  C  C  {  ?
clé :     ?        77 81 1c e8 ?
```
Encore huit lignes plus loin :
```
chiffré : fa7ced3342b02995 a1 a9 67 5f d2515a26
clair :   ?                G  C  C  {  ?
clé :     ?                e6 ea 24 24 ?
```
Et enfin :
```
chiffré : ff44d46d16e643dad3db1159 e5 60 7c 29
clair :   ?                        G  C  C  {  
clé :     ?                        a2 23 3f 52
```
La clé qui a chiffré le flag lorsque le LCG est arrivé sur un point fixe est donc :
`0x9b1bb20177811ce8e6ea2424a2233f52`
On fait ensuite un simple xor entre les 32 derniers octets du chiffré et notre clé et l'on obtient le flag !
> GCC{pretend_its_a_good_flag_2515}
