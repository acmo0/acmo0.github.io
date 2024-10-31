---
layout: post
title: J'ai glissé chef !
tags: Write-up 404CTF 2024 crypto slide-attack
---
![](https://acmo0.github.io/assets/img/j_ai_glisse_chef_screenshot.png)

# Informations générales
Nous avons affaire à un chiffrement par bloc, suivant un [schéma de Feistel](https://fr.wikipedia.org/wiki/R%C3%A9seau_de_Feistel) avec quelques détails assez étrange : il y a deux clés qui se répètent en alternant suivant le round et un nombre de round assez grand (96 rounds). Chaque clé fait 32 bits, une clé peut se bruteforcer mais les deux clés ne peuvent pas de bruteforcer. Il est à noter qu'aucun bruteforce des clés n'est nécessaire pour résoudre ce challenge.

# Résolution

Cet algorithme est vulnérable à une [Slide Attack](https://en.wikipedia.org/wiki/Slide_attack) particulière. Une attaque par cryptanalyse différentielle ou linéaire semble compliquée ici justement à cause du nombre important de rounds. L'idée est de faire une attaque `slide with a twist` comme décrite dans [cet article](https://www.iacr.org/archive/eurocrypt2000/1807/18070595-new.pdf). Une fois la première clé récupérée, on peut suivre le reste de l'article (dont l'explication est assez vague) pour récupérer la seconde clé. Sinon, on peut "shifter" notre algoritme de chiffrement puis réitérer la même attaque, ce qui est plus rapide car toutes les fonctions sont déjà implémentées pour récupérer la première clé !

## Première clé
Pour notre slide attack, on doit générer beaucoup de textes à chiffrer / déchiffrer par notre oracle de chiffrement en espérant tomber sur une paire de clairs/chiffrés qui satisfasse certaines conditions particulière. En utilisant le paradoxe des anniversaires, on estime qu'il faut environ 2^16 clairs et 2^16 chiffrés pour récupérer la première clé. Voici comment les clairs/chiffrés sont générés (c.f article) : 
```python
def get_pool():
	pool1 = []									# act as plaintexts
	r = os.urandom(4)
	for i in range(2**16):
		print(round(i/2**16*100,2),end="\r")
		l = os.urandom(4)
		pool1.append(l+r)
	pool2 = []									# act as ciphertexts
	for i in range(2**16):
		print(round(i/2**16*100,2),end="\r")
		l = os.urandom(4)
		pool2.append(l+r)
	return pool1,pool2
```

Ensuite, on demande le chiffrement de la première pool et le déchiffrement de la deuxième pool par l'oracle mis à disposition.
L'idée est ensuite de trouver une paire qui satisfasse certaines conditions décrites dans l'article, une fois une telle paire trouvée, la déduction de la première clé est immédiate.

Cette méthode permet donc, pour un réseau de Feistel quelconque vulnérable à une slide attaque de retrouver la première clé. Afin de réutiliser ce qui a déjà été codé, il serait utile de se ramener exactement au même problème que précédement mais en changeant l'alternance des clés de chiffrement utilisées comme décrit dans la figure suivante :

![shiffted_cipher](https://acmo0.github.io/assets/img/diag1.png)

Pour cela, on met en place le système suivant :
![shiffter_cipher2](https://acmo0.github.io/assets/img/diag2.png)

Cela nous permet d'avoir exactement le réseau de Feistel désiré pour ré-itérer la même attaque déjà implémentée pour obtenir la seconde clé. Après avoir "entouré" notre oracle par un déchiffrement d'un round avec clé 1 avant et un chiffrement d'un round avec la clé 1 après, il suffit de recommencer et on obtient la seconde clé.

Solution en python3 :
```python
# 404CTF 2024
# Challenge : J'ai glissé chef,  
# Authors : acmo0

from Cryptodome.Util.number import bytes_to_long,long_to_bytes
import socket
import os
Sbox = (
	0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
	0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
	0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
	0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
	0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
	0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
	0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
	0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
	0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
	0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
	0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
	0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
	0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
	0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
	0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
	0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16
)

Sbox_inv = [ Sbox.index(i) for i in range(len(Sbox))]

def f_inv(block):
	b4 = (block>>24) & 0xff
	b3 = (block>>16) & 0xff
	b2 = (block>>8) & 0xff
	b1 = block & 0xff
	b4 ^= b3
	b4 = Sbox_inv[b4]
	b3 = Sbox_inv[b3]
	b3 ^= b1
	b1 ^= b2
	b2 = Sbox_inv[b2]
	b2^=b1
	b1 = Sbox_inv[b1]
	return (b1<<24)+(b2<<16)+(b3<<8)+b4

def f(block):
	b1 = (block>>24) & 0xff
	b2 = (block>>16) & 0xff
	b3 = (block>>8) & 0xff
	b4 = block & 0xff
	b1 = SBox[b1]
	b2 ^= b1
	b2 = SBox[b2]
	b1 ^= b2
	b3 ^= b1
	b3 = SBox[b3]
	b4 = SBox[b4]
	b4 ^= b3
	return (b4<<24)+(b3<<16)+(b2<<8)+b1


def get_pool():
	pool1 = []
	r = os.urandom(4)
	for i in range(2**16):
		print(round(i/2**16*100,2),end="\r")
		l = os.urandom(4)
		pool1.append(l+r)
	pool2 = []
	for i in range(2**16):
		print(round(i/2**16*100,2),end="\r")
		l = os.urandom(4)
		pool2.append(l+r)
	return pool1,pool2

def encrypt_pool(c,p):
	e_p = [None for i in range(len(p))]
	for i in range(len(e_p)):
		print(round(i/2**16*100,2),end="\r")
		e_p[i] = (bytes_to_long(p[i]),bytes_to_long(c.encrypt(p[i])))
	return e_p

def decrypt_pool(c,p):
	d_p = [None for i in range(len(p))]
	for i in range(len(d_p)):
		print(round(i/2**16*100,2),end="\r")
		d_p[i] = (bytes_to_long(p[i]),bytes_to_long(c.decrypt(p[i])))
	return d_p

def find_pair(p1,p2):
	pairs = []
	key = None
	hash_table = {}
	for pair1 in p1:
		lr,mn = pair1
		l = lr>>32
		r = lr&0xffffffff
		n = mn&0xffffffff
		m = mn>>32
		if not n in hash_table:
			hash_table[n] = [pair1]
		else:
			hash_table[n].append(pair1)
	for pair2 in p2:
		mn_prime,lr_prime = pair2
		r_prime = lr_prime&0xffffffff	
		l_prime = lr_prime>>32
		m_prime = mn_prime>>32
		n_prime = mn_prime&0xffffffff
		if r_prime in hash_table:
			for pair1 in hash_table[r_prime]:
				lr,mn = pair1
				l = lr>>32
				r = lr&0xffffffff
				n = mn&0xffffffff
				m = mn>>32
				if f_inv(m_prime^l)^r == f_inv(l_prime^m)^n:
					key = f_inv(m_prime^l)^r
					print("Found potential :",hex(f_inv(m_prime^l)^r), hex(f_inv(l_prime^m)^n))
					pairs.append((pair1,pair2))
	return pairs,key

def partial_encrypt(k,text):
	l = text>>32
	r = text&0xffffffff
	l ^= f(r^k)
	return l+(r<<32)

def partial_decrypt(k,text):
	l = text >>32
	r = text &0xffffffff
	l,r = r,l
	l^= f(k^r)
	return 	(l<<32)+r

class DistantCipher:
	def __init__(self,s):
		self.s = s

	def encrypt(self,block):
		s.send(b"encrypt "+block.hex().encode('utf-8')+b"\n")
		rcv = self.s.recv(1024)
		return bytes.fromhex(rcv.decode('utf-8').replace("\n",""))

	def decrypt(self,block):
		s.send(b"decrypt "+block.hex().encode('utf-8')+b"\n")
		rcv = self.s.recv(1024)
		return bytes.fromhex(rcv.decode('utf-8').replace("\n",""))

class ShiftedCipher:
	def __init__(self,k,cipher):
		self.k = k
		self.cipher = cipher

	def encrypt(self,text):
		text = long_to_bytes(partial_decrypt(self.k,bytes_to_long(text)),blocksize=8)
		text = bytes_to_long(self.cipher.encrypt(text))
		return long_to_bytes(partial_encrypt(self.k,text),blocksize=8)

	def decrypt(self,text):
		text = long_to_bytes(partial_decrypt(self.k,bytes_to_long(text)),blocksize=8)
		text = bytes_to_long(self.cipher.decrypt(text))
		return long_to_bytes(partial_encrypt(self.k,text),blocksize=8)


HOST = "challenges.404ctf.fr"
PORT = 31953

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST,PORT))
print(s.recv(1024).decode('utf-8'))

cipher = DistantCipher(s)

print("Generate pool")
p1,p2 = get_pool()
print("encrypt pool")
p1_e = encrypt_pool(cipher,p1)
print("decrypt pool")
p2_e = decrypt_pool(cipher,p2)
print("Find pairs")
pairs,k = find_pair(p1_e,p2_e)
while len(pairs)==0:
	print('No pairs, retry')
	print("Get pool")
	p1,p2 = get_pool()
	#print(p1[:10],p2[:10])
	print("encrypt pool")
	p1_e = encrypt_pool(cipher,p1)
	print("decrypt_pool")
	p2_e = decrypt_pool(cipher,p2)
	print("find pairs")
	pairs,k = find_pair(p1_e,p2_e)


print("Found first key",k)

cipher2 = ShiftedCipher(k,cipher)
print("Get pool")
p1,p2 = get_pool()
print("encrypt pool")
p1_e = encrypt_pool(cipher2,p1)
print("decrypt pool")
p2_e = decrypt_pool(cipher2,p2)
print("find pair")
pairs,k2 = find_pair(p1_e,p2_e)
while len(pairs)==0:
	print('No pairs, retry')
	print("Get pool")
	p1,p2 = get_pool()
	print("encrypt pool")
	p1_e = encrypt_pool(cipher2,p1)
	print("decrypt pool")
	p2_e = decrypt_pool(cipher2,p2)
	print("find pair")
	pairs,k2 = find_pair(p1_e,p2_e)

print("Found second key :",k2)

s.send(b"check "+hex(k)[2:].encode('utf-8')+b" "+hex(k2)[2:].encode('utf-8')+b"\n")
print(s.recv(1024))
```