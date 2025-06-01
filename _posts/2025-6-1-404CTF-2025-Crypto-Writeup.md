---
layout: post
title: 404CTF 2025 Crypto Writeups
subtitle: One of my challenge for the 404CTF 2025
tags: Write-up 404CTF2025 crypto symetric personnal-challenge
katex: true
---

- [SpaceMark - *medium*](#spacemark)
- [Dérive dans l'espace - *medium*](#dérive-dans-lespace)
- [More Space - *extreme*](#more-space)

***

# SpaceMark
*Level : medium*

## Context
To solve this challenge, we have to retrieve what is called the `generating bits` for a given watermark. To achieve this, we have access to an online oracle over TCP, that choose randomly the so called `generating bits` and generate a watermark. If the user is able to submit correctly to the oracle the random bits, the oracle gives the flag.
> At first, this challenge was not interractive. Instead, the watermark was generated once, and the outputed bits were added to the pixels of an image. This explains the *watermarking aspect* of the challenge, that was not linked to the released challenge anymore during the CTF.

## Solve
Let's take a look at generation process.

Firstly, we have a LCG implementation (nothing supsicious for now) :
```python
class LCG:
	def __init__(self, a, b, m, seed):
		self.state = seed
		self.a = a
		self.b = b
		self.m = m

	def next(self):
		s = self.state
		self.state = (self.a * self.state + self.b) % self.m

		return s
```
Instance of such LCG will be written : $LCG(a, b, m, seed)$

Then we have the main component to generate our watermark :
```python
def generate_watermark(watermarking_bits, size):
	m = 2 ** 64
	b = 2 * randint(2, m - 1) + 1
	a = 2 * randint(2, m - 1) + 1

	while a % 8 != 5:
		a = 2 * randint(2, m - 1) + 1

	stream = []
	for bit in watermarking_bits:
		seed = randint(2, m - 1)
		l = LCG(a, b, m + bit, seed)
		for _ in range(size):
			stream.append((l.next() >> 11) & 1)

	return stream
```
How this works ?
- Get as input a bit array that will generate the watermark
- Set $m=2^{64}$ and choose randomly $a$ and $b$ such that 
$$a = 2r + 1,\ b=2r'+1$$
with 
$2 \leq r, r' \leq m-1$ So, $a$ and $b$ are random odd numbers. Moreover, we have $a \neq 5 \mod 8$.
- For each input bit :
	- Instanciate a LCG $LCG(a, b, m, randomSeed)$ if the considered bit is zero, else $LCG(a, b, m + 1, randomSeed)$
	- Output *size* times the 12-th bit of the generated number by the LCG

The last part is how this function used :
```python
print("Welcome to Spacemark ! Can you guess my secret data used to generate the watermark ?")
size = 2**12

random_watermark = os.urandom(16)

random_watermark = "".join([format(b, "08b") for b in random_watermark])
random_watermark_bits = list(map(int, list(random_watermark)))

watermark = json.dumps(
	generate_watermark(random_watermark_bits, size)
)

print(zlib.compress(watermark.encode()).hex())

print("So, what's the watermark ?")

guess = input(">>>")

if guess == random_watermark:
	print(f"Congratz ! {FLAG}")
else:
	print("Nope...")
	print(random_watermark)

exit()
```
This generates a 16 bytes secret, use this secret to generate a watermark, sends it to the user and then asks for the 16 bytes secret to give the flag. Moreover, we have $2^{12}$ consecutive outputs (the 12-th bit only) of the LCG for each secret bit.

**How to retrieve the secret bits ?**

What we want is to be able to distinguish beteween a zero and a one as the secret bit used to generate each part of the watermark. To find how to achieve this, first we should look at what's different during the process of generation :
- $a$ - *similar (random)*
- $b$ - *similar (random)*
- $seed$ - *similar (random)*
- $modulus$ - *different ($2^{64}$ when the bit is zero, $2^{64} + 1$ otherwise)*

There is an interesting property when the modulus that holds when the modulus is a power of two and $a$ and $b$ are generated in the way they are in this challenge :
> Correctly chosen parameters allow a period equal to m, for all seed values. This will occur if and only if:
- $m$ and $c$ are coprime,
- $a-1$ is divisible by all prime factors of $m$,
- $a−1$ is divisible by 4 if $m$ is divisible by 4.<br><br>
Note that a power-of-2 modulus shares the problem as described above for c = 0: the low k bits form a generator with modulus $2^k$ and thus repeat with a period of $2^k$; only the most significant bit achieves the full period.

*(from [wikipedia](https://en.wikipedia.org/wiki/Linear_congruential_generator#m_a_power_of_2,_c_%E2%89%A0_0))*

This is a serious issue, because the protocol fits exactly these conditions for such a property to hold when the input bit is equal to zero. Moreover, this property does not hold when the modulus is not a power of two : this will allow us to distinguish the input bits.
We know that the 12-th bit achieves the full period of $2^{12}$ when $m=2^{64}$, *i.e* when in a block of $2^{12}$ bits we have exactly half of the bits equal to one, then it is very probable that the modulus is $2^{64}$, *i.e* that the input bit is a zero.

We use this method on each $2^{12}$ consecutive block of bits to recover the input bits one by one. Sometimes, this fails because it can happen that there is exactly $2^{11}$ bits equal to one in a block when the modulus is $2^{64}+1$, so one may need to run the solve again to get the flag.

***

# Dérive dans l'espace
*Level : medium*

## Context
To solve this challenge, we have a small Rust lib that implements AES128 and a custom key derivation function (KDF), and a Rust program that uses this lib to encrypt sensitive data (the flag) and send it over UDP. We also have a PCAP file which contains all the packets send over UDP to the remote server.

There are two main approaches to solve this challenge, the first way is : run the code and observe some properties to find out what element is broken in the Rust lib. The other way is to read the code inside the lib to detect a potential bug.

## Solve
The `main.rs` file basically just uses the lib to send many times the packet encrypted with random master keys to feed the KDF. It is probable that the bug is inside the lib itself, rather than in the way it is used. 

To verify that, one might first look at the AES128 implementation. To test it efficiently, I recommend using some test vectors from the NIST to verify the correct implementation ; from that point, we can confirm that the AES128 implementation is correct.

Now, let's focus on the KDF. Here is a simplified pseudocode :

![KDF algo](/assets/img/algo_kdf.png)

What can go wrong with this algorithm ?
- The random index generated should be strong enough (c.f [this page](https://rust-random.github.io/book/guide-rngs.html) from the Rust handbook)
- The initial matrix $M$ has good diffusion properties (MDS matrix)

While the algorithm might be (and is surely) a very very bad key derivation algorithm, there is no big issue at first sight. Moreover, the matrix multiplication implementation is correct. But what about the swap ? Well, instead of using a temporary variable to swap the two elements it uses the [XOR swap method](https://en.wikipedia.org/wiki/XOR_swap_algorithm), nothing really suspicious but what if the value of $counter$ is equal to the random value of $i$ ? Well, then this will set to zero the value at the index $i$. So, the more key you derivate, the more probable it becomes that $M$ has zeros coefficient, which leads directly to a key with lots of zeros bytes.

At the 200th key derivation iteration (i.e at the last key derivation computed to send the last packet), there is approx. 19.2% of keys that will be made only of null bytes.

When we take a look at the pcap file, there are about 12500 packets, so approximately 60 different exchanges using the given code.
The last step is to get a packet from the pcap where the key used is null. To spot such packet, first one should take the last packet of each exchange, then take the last 16 bytes as the IV and finally try to decrypt the packet using a null key. A correct packet is easily spotted by checking if the first bytes match the PNG header format (the flag is a png file).

The flag is just the image decrypted.

***

# More Space

| Category   | Crypto |
|------------|--------|
| Difficulty | Insane |
| Solves     | 3      |
|------------|--------|

## Cipher overview
This cipher has the following properties :
- Block size of 64 bits
- Feistel scheme
- 2 S-Boxes (7 bits and 9 bits)
- 6 rounds

***

## Solve idea

Basic idea of the intended solve:
- Analysis of SBoxes : they have low algebraic degree (degree 3)
- Use Feistel network structure to find a distinguisher based on high order differential
- Recover last round key
- Recover 5th round key
- Get the flag

Next will come as soon as possible...

<!--
***

## Detailed solve
### Permutation analysis
This permutation is really bad and leads also to another solve that was uninteded using impossible truncated differential cryptanalysis. In fact, because of the permutation, some S-Boxes are not active, allowing us to retrieve the plaintext more efficiently than in this write-up.
***
### S-Boxes anaylsis
#### 7-bit S-Box
```
- maximum differential probability : 0.016
- maximal linear bias : 0.062
- is almost bent
```
This S-Box seems kinda good, however when we look at the degree of it in $\mathbb{F}_{2^7}$ using sage, we have:
```python
F7 = GF(2^7)
R7.<x> = PolynomialRing(F7)

# Use lagrange interpolation to get the polynomial that generate this S-Box
p = R7.lagrange_polynomial(
	[
		(F7.from_integer(i), F7.from_integer(S1[i])) for i in range(128)
	]
)

print(p)
# Ouputs :
# 	(z7^6 + z7^5 + z7^4 + z7^3 + z7^2 + z7 + 1)*x^3
# 	+ (z7^4 + z7^3 + 1)*x^2 + (z7^5 + z7^2 + 1)*x
# 	+ z7^5 + z7^4 + z7^3 + z7^2 + 1
```
In a nutshell, this S-Box has a very low algebraic degree of 3. This might be exploitable regarding that the cipher is only made of 6 rounds.
#### 9-bit S-Box
```
- maximal differential probability : 0.004
- maximal linear bias : 0.031
- is almost bent
```
We proceed in the same way but in $\mathbb{F}_{2^9}$:
```python
F9 = GF(2^9)
R9.<x> = PolynomialRing(F9)

# Use lagrange interpolation to get the polynomial that generate this S-Box
p = R9.lagrange_polynomial(
	[
		(F9.from_integer(i), F9.from_integer(S2[i])) for i in range(512)
	]
)

print(p)
# Ouputs :
#	(z9^8 + z9^4 + z9^2 + z9)*x^3
#	+ (z9^8 + z9^6 + z9^3 + z9^2 + 1)*x^2
#	+ (z9^7 + z9^6 + z9^4 + z9^2 + z9 + 1)*x
#	+ z9^8 + z9^7 + z9^5 + z9^4 + z9^3 + 1
```
This S-Box suffers of the same design issue as the first one.

***

### Higher Order differential Distinguisher
Let's take a look at the degree for each round of the cipher.
The round function $f$ can be considered as a polynomial function of degree 3. In fact only the S-Boxes affect the total degree of $f$.
Here is a schematic of the cipher along with the degree of each half part.
![](/assets/img/cipher-degree.svg)

-->