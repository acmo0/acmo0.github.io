---
layout: post
title: Poor Random Number Generator [1/2]
tags: Write-up 404CTF 2024 crypto easy
---
![](https://acmo0.github.io/assets/img/prng1_screenshot.png)

# Résolution

En regardant le code fourni, on déduit les informations suivantes :
- Le chiffré est un fichier PNG
- La fonction encrypt utilise un objet nommé *Generator* pour générer un flot de chiffrement qui va être xoré avec le fichier en clair
- Le générateur est initialisé avec 2000 octets avec la fonction `os.urandom` (normalement suffisante pour des applications cryptographiques):
```python
self.feed = [int.from_bytes(os.urandom(1)) for i in range(2000)]
```
- Pour générer un octet, le générateur applique une fonction sur son état interne de 2000 octets, renvoie le résultat de la fonction appliquée et remplace le premier octet de l'état par ce nombre calculé

De plus on dispose du début en clair du fichier *flag.png*.
À partir du clair et du chiffré, en faisant un XOR des deux, on peut récupérer une partie du flot généré par l'objet *Generator*. Puisque le clair connu fait 2293 octets, on est en capacité de récupérer l'état du générateur en faisant un XOR avec le chiffré. À partir de là on initialise un objet *Generator*, on initialise la variable `feed` avec les 2000 premiers octets, on génénère un flot qui fait la taille du chiffré puis on fait un XOR du fichier chiffré et du flot généré (plus les 2000 premiers octets) et on récupère le fichier PNG.

Voici la solution implémentée en python3 :
```python
# 404CTF 2024
# Challenge : Poor Random Number Generator 1, medium
# Authors : acmo0

from my_random import Generator

def get_blocks(data,block_size):
	return [data[i:i+block_size] for i in range(0,len(data),block_size)]

def xor(b1, b2):
    return bytes(a ^ b for a, b in zip(b1, b2))

def pad(data,block_size):
	return data+b'\x00'*(len(data)%block_size)

def encrypt(data,block_size,generator):			# fonction encrypt du fichier du challenge (pareil que déchiffrer, cf XOR)
	padded_data = pad(data,block_size)
	data_blocks = get_blocks(padded_data,block_size)
	encrypted = b''
	i = 0
	for block in data_blocks:
		print(round(i/len(data_blocks)*100,2),"%",i,end="\r")
		rd = generator.get_random_bytes(block_size)
		encrypted += xor(block,rd)
		i+=1
	return encrypted

clear = open("flag.png.part",'rb').read()[:2000]
enc = open("flag.png.enc",'rb').read()[:2000]

BLOCK_SIZE = 4
flag = None


feed = list(b''.join([xor(clear[i:i+4],enc[i:i+4]) for i in range(0,2000,4)]))		# xor entre le clair et le chiffré -> 2000 premiers octets du flot 

g = Generator()
g.feed = feed # initialise le feed avec celui récupéré 



with open("flag.png.enc",'rb') as f:
	flag = f.read()

with open('flag_dec.png', 'w+b') as f:
	e = encrypt(flag[2000:],BLOCK_SIZE,g)	# déchiffre le reste du PNG
	f.write(clear[:2000]+e)					# écrit le clair connu + déchiffré
```