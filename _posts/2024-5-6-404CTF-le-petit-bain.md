---
layout: post
title: Le petit bain
categories: Write-up 404CTF 2024 crypto easy
---
![](images/le_petit_bain_screenshot.png)
# Résolution
Il s'agit de la suite du challenge *Bébé nageur*. Ce challenge est inspiré du principe de chiffrement par blocs avec un chiffrement affine. Ce chiffrement est composé de 6 rounds, chaque round a la forme suivante : 
![round_schema](https://acmo0.github.io/images/diag1.drawio.png)
Cependant, on remarque deux propriétés particulières de cette permutation `p`:
- `p^6` est l'identité
- Pour chaque sous-bloc de 6 caractères, la permutation est identique

Ainsi, avec 6 rounds, la permutation peut finalement être ignorée. De plus, on peut se ramener à la cryptanalyse d'un seul bloc de 6 caractères, au lieu d'un bloc de 48 caractères.
De plus, chaque caractère va subir 6 chiffrements affines. Or une composition de chiffres affines reste un chiffre affine. Par exemple si l'on compose deux chiffres affines, on a :
```
c1(x) = a1*x + b1 [n]
c2(x) = a2*x + b2 [n]

c2(c1(x)) a2*( a1*x + b1 ) + b2 = a1*a2*x + (a2*b1 + b2) [n]
```

Ainsi, on a donc finalement pour chaque caractère d'un bloc de 6 caractères un chiffrement du type : `c(x) = Ax + B [n]`, qui est un problème similaire à celui rencontré dans *Bébé nageur*. Sachant que l'on connaît deux blocs deux 6 caratères grâce à la ligne
```python
assert FLAG[:12] == "404CTF{tHe_c"
```
dans le fichier *challenge.py*, on peut alors effectuer la même attaque que pour *Bébé nageur*.

Solution implémentée en python3 :
```python
# 404CTF 2024
# Challenge : Le Petit Bain, easy
# Authors : acmo0 & Little_endi4ne

encrypted = "C_ef8K8rT83JC8I0fOPiN6P!liE03W2NXFh1viJCROAqXb6o"
clear = "404CTF{tHe_c"

charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{}_-!"
n = len(charset)

def f(a,b,n,x):
	return (a*x+b)%n

def f_inv(a,b,n,x):
	return ((x-b)%n)*pow(a,-1,n)%n


def decrypt(message):
	decrypted = ""
	for i in range(len(message)):
		x = charset.index(message[i])
		a = A[i%6]
		b = B[i%6]
		x = f_inv(a,b,n,x)
		decrypted += charset[x]
	return decrypted

A,B = [],[]

for i in range(6):
	x1 = charset.index(clear[i])
	y1 = charset.index(encrypted[i])
	x2 = charset.index(clear[i+6])
	y2 = charset.index(encrypted[i+6])
	a = ((y2 - y1)%n)*pow((x2-x1)%n,-1,n)%n
	A.append(((y2 - y1)%n)*pow((x2-x1)%n,-1,n)%n)
	B.append((y1 - a*x1)%n)


print(decrypt(encrypted))
```