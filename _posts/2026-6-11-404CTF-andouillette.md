---
layout: post
title: Andouillette
subtitle: One of my crypto challenge for 404CTF
tags: Write-up 404CTF 2026 crypto symetric
katex: true
---

# Adouillette - revenge

> Note : the "revenge" comes from the fact that the first version of
the challenge had a logical flaw allowing to completely bypass the crypto
part of it.

## TL;DR
- Based on generic Yoyo distinguisher for two-rounds SPN from [`[1]`](https://eprint.iacr.org/2017/980)
- Use mega-sbox representation, similarly to super-sbox representation of AES [`[2]`](https://link.springer.com/chapter/10.1007/978-3-662-45611-8_11) and pholkos [`[3]`](https://tosc.iacr.org/index.php/ToSC/article/view/9177) to represent the whole cipher as a two round SPN
- Play the deterministic yoyo game using encryption/decryption to obtain a distinguisher
- Repeat the distinguisher 64 times to obtain the flag

## Challenge analysis
The cipher code is given in [Appendix A](#a). You can also find it on Github (see appendix for full details).

We are given a cipher with a block and key size of 128 bits.
To win the flag we need to answer the following question 64 times: does the server encrypt/decrypt my requests using a cipher or a random oracle ?
Of course we need to find an efficient way to answer this question, otherwise the probability
of obtaining the flag is around $2^{-64}$.

## Cipher analysis
The block cipher is a [substitution permutation network](https://en.wikipedia.org/wiki/Substitution%E2%80%93permutation_network) (SPN). It is decomposed as two substates of 64 bits
divided in 16 nibbles. A single round function (let's call it $R$) applied in parallel on each state. This function is made of the following transformations:

- $ARK$ : add (xor) the round key with the state,
- $S$ : a SBox, from the PRESENT cipher,
- $P$ : a swap of rows that can be represented using this permutation matrix
  $$\begin{pmatrix}
0 & 1 & 0 & 0 \\
0 & 0 & 0 & 1 \\
1 & 0 & 0 & 0 \\
0 & 0 & 1 & 0 \\
\end{pmatrix}$$  and then a transposition of the resulting matrix

- $MC$ : a MixColumns-like matrix multiplication by the MDS matrix  $$M = \begin{pmatrix}
d & 7 & a & 3 \\
7 & d & 3 & a \\
a & 3 & d & 7 \\
3 & a & 7 & d \\
\end{pmatrix}$$


- Then eventualy another mixing operation is applied which is a simple affine function in $F_2^{64}$ on the entire substate. Note that the coefficients depend on the round number: $x \mapsto a_r x + b_r$. Also note that this operation is affine when looking at nibbles in $F_2^4$.

> Notations : I refer by $R^-$ to a round without the last affine transformation and $R$ a round with it.

The following figure illustrate how a full round act on the input rows.


<img src="/assets/img/andouillette/round.svg" style="width: 100%;">



Finally, a nibble permutation $\Pi$ is eventually applied such that it shuffles the two substates together with this permutation


$$\chi := [
0  \ 4  \ 8  \ 12 \ 
16 \ 20 \ 24 \ 28 \ 
18 \ 22 \ 26 \ 30 \ 
2  \ 6  \ 10 \ 14 \ 
1  \ 5  \ 9  \ 13 \ 
17 \ 21 \ 25 \ 29 \ 
19 \ 23 \ 27 \ 31 \ 
3  \ 7  \ 11 \ 15
]
$$ 

and then transpose each state in parallel.

Here is the overall cipher structure :


<img src="/assets/img/andouillette/cipher.svg" style="width: 100%;">


## A Mega-SBox representation
As there exists a Super-SBox representation of AES [`[2]`](https://link.springer.com/chapter/10.1007/978-3-662-45611-8_11), one can find what can be called a Mega-SBox reprensentation for our cipher. In fact, similar observations has already been done on Pholkos [`[3]`](https://tosc.iacr.org/index.php/ToSC/article/view/9177).
Such a Mega-SBox spans over almost 4 rounds of the cipher and is 64 bits wide. Here is a visual representation of that Mega-SBox:

<img src="/assets/img/andouillette/megasbox.svg" style="width: 100%;">


If you forget for now the last $MC$ and $M$ (the affine function over $\mathbb{F}_2^{64}$),
then we clearly see that red and blue nibbles are following an independent path that acts as a 64 bits SBox.

This representation is the key observation of this challenge, as it will allow us to build a distinguisher. Now the whole cipher is simply $$megaSbox_2\circ M \circ MC \circ megaSbox_1$$ i.e. a (Mega-)SBox layer followed by a linear layer $$M\circ MC$$ and another (Mega-)SBox layer.

## Yoyo distinguisher

> Note: I suggest to read before or at the same time as the following part with [`[1]`](https://eprint.iacr.org/2017/980) to have a better understanding of the attack.


**Notations**

- I represent a SPN state made of $n$ words in $\mathbb{F}_2^k$ as $(w_1,\ldots, w_n) \in (\mathbb{F}_2^k)^n$,
- Let $\alpha\in (\mathbb{F}_2^k)^n$ then $$\nu: \alpha \mapsto (a_1, \ldots, a_n)$$ where $a_i = 0$ iff the $i$-th word in $\alpha$ is zero, otherwise $a_i = 1$,
- Let $\alpha, \beta \in (\mathbb{F}_2^k)^n$, and $v \in \lbrace 0, 1\rbrace^n$ then $\rho^v : (\alpha, \beta) \mapsto (\gamma_1, \ldots, \gamma_n)$ where $$\gamma_i = \begin{cases} \alpha_i & \mathrm{if}\ v_i = 1\\ \beta_i & \mathrm{if}\ v_i=0 \end{cases}$$

> Note that $(\rho^v(\alpha, \beta), \rho^v(\beta, \alpha))$ is then just a pair of state where the $i$-th word is swaped between $\alpha$ and $\beta$ if $v_i=0$.

**Properties from `[1]`**

From [`[1]`](https://eprint.iacr.org/2017/980), we know that for any two-rounds SPN made of an affine layer $L$ and sboxes $S$ ($S$ may be different at each round) :


$$\nu(S\circ L \circ S (\alpha) \oplus S\circ L \circ S (\beta)) = 
\nu(S\circ L \circ S (\rho^v(\alpha, \beta)) \oplus S\circ L \circ S (\rho^v(\beta, \alpha)))$$

Or in short if we pose $E = S\circ L \circ S$ :

$$
\nu (E(\alpha)\oplus E(\beta)) = \nu(E(\rho^v(\alpha, \beta)) \oplus E(\rho^v(\beta, \alpha)))
$$


This means that the activity pattern ($\nu$) is preserved when some independent words are swapped. Note that it also works for decryption since $E^{-1}$ is also a two-round SPN, we will use this exact property to distinguish the cipher from a random permutation.

**Distinguisher**

Here is the idea of the distinguisher :
- Take two plaintexts $\alpha = (\*, 0)$ and $\beta = (\*, 0)$. The first coordinate of the plaintexts corresponds to the first Mega-SBox (i.e the first two lines of each state) and is chosen at random while the second word corresponds to the second Mega-SBox and is set to zero (in fact it can be anything as long as they are equal),
- We know that $\nu(\alpha \oplus \beta) = (1, 0)$ with overwhelming probability,
- Ask for the encryption of $\alpha$ and $\beta$ to obtain $c_\alpha$ and $c_\beta$,
- Swap a word between $c_\alpha$ and $c_\beta$ to obtain $c_\alpha'$ and $c_\beta'$,
- Ask for the decryption of $c_\alpha'$ and $c_\beta'$ to obtain $\alpha'$ and $\beta'$,
- Compute $a = \nu(\alpha' \oplus \beta')$
- If $a = \nu(\alpha \oplus \beta)$ then our distinguisher worked and we were dealing with the cipher, otherwise we were dealing with a random oracle.

> I strongly recommend to read `[1]` to fully understand why it is working


## Going further

Such attack belongs to the family of structural attacks and is somewhat related to exchange attacks [`[5]`](https://eprint.iacr.org/2019/652), mixture differential cryptanalysis (as well as multiple of eight) [`[4]`](https://eprint.iacr.org/2017/832.pdf). The fundamental idea of these attacks is to exploit the strong structure of the SPN, allowing to be somewhat agnostic to the details of the SBoxes and find another representation of the cipher. This idea has proved to be powerful against AES-like ciphers and derivatives as the structure is very strong.


**Solve script**

We can easily implement the distinguisher in python (the PoW part is not included) :

```python
from pwn import *
import os
from copy import copy

def xor(a, b):
    return bytes([e1 ^ e2 for e1, e2 in zip(a, b)])

# This is nu in the article
def zdp(a, b):
    d = xor(a, b)
    return [
        int(d[:4] == b"\x00" * 4 and d[8:12] == b"\x00" * 4),
        int(d[4:8] == b"\x00" * 4 and d[12:] == b"\x00" * 4),
    ]

r = remote("challenge.404ctf.fr", 10009)

for i in range(64):
    print(i)
    print(r.recvuntil(b">>> "))

    # Ask for the encryption of alpha/beta
    pt1 = (os.urandom(4) + b"\x00" * 4) * 2
    pt2 = (os.urandom(4) + b"\x00" * 4) * 2

    r.sendline(b"1")
    print(r.recvuntil(b">>> "))
    r.sendline(pt1.hex().encode())

    ct1 = bytes.fromhex(r.recvuntil(b">>> ").decode().split("\n")[0].split(" ")[1])

    r.sendline(b"1")
    print(r.recvuntil(b">>> "))
    r.sendline(pt2.hex().encode())

    ct2 = bytes.fromhex(r.recvuntil(b">>> ").decode().split("\n")[0].split(" ")[1])
    
    ct1 = list(ct1)
    ct2 = list(ct2)

    # Swap one mega-sbox
    tmp = copy(ct1[2:6])
    ct1[2:6] = copy(ct2[2:6])
    ct2[2:6] = copy(tmp)

    tmp = copy(ct1[10:14])
    ct1[10:14] = copy(ct2[10:14])
    ct2[10:14] = copy(tmp)

    # Ask for the decryption
    r.sendline(b"2")
    print(r.recvuntil(b">>> "))
    r.sendline(bytes(ct1).hex().encode())

    rcv = r.recvuntil(b">>> ")
    print(rcv)
    pt1_p = bytes.fromhex(rcv.decode().split("\n")[0].split(" ")[1])

    r.sendline(b"2")
    print(r.recvuntil(b">>> "))
    r.sendline(bytes(ct2).hex().encode())

    rcv = r.recvuntil(b">>> ")
    print(rcv)
    pt2_p = bytes.fromhex(rcv.decode().split("\n")[0].split(" ")[1])

    print("PT", pt1.hex(), pt2.hex())
    print("CT", bytes(ct1).hex(), bytes(ct2).hex())
    print("PT2", pt1_p.hex(), pt2_p.hex())
    print(zdp(pt1, pt2), zdp(pt1_p, pt2_p))

    # If the inactivity pattern is the same
    # then distinguish as cipher otherwise random
    if zdp(pt1, pt2) == zdp(pt1_p, pt2_p):
        r.sendline("Cipher")
    else:
        r.sendline("Random")

# print the flag
print(r.recvline())
```


## References
`[1]` Sondre Rønjom and Navid Ghaedi Bardeh and Tor Helleseth, Yoyo Tricks with AES, Cryptology ePrint Archive, [https://ia.cr/2017/980](https://ia.cr/2017/980)


`[2]` Gilbert, H. (2014). A Simplified Representation of AES. In: Sarkar, P., Iwata, T. (eds) Advances in Cryptology – ASIACRYPT 2014. ASIACRYPT 2014. Lecture Notes in Computer Science, vol 8873. Springer, Berlin, Heidelberg. [https://doi.org/10.1007/978-3-662-45611-8_11](https://doi.org/10.1007/978-3-662-45611-8_11)


`[3]` Rahman, M., Saha, D., & Paul, G. (2021). Boomeyong: Embedding Yoyo within Boomerang and its Applications to Key Recovery Attacks on AES and Pholkos. IACR Transactions on Symmetric Cryptology, 2021(3), 137-169. [https://doi.org/10.46586/tosc.v2021.i3.137-169](https://doi.org/10.46586/tosc.v2021.i3.137-169)


`[4]` Lorenzo Grassi. Mixture Differential Cryptanalysis and Structural Truncated Differential Attacks on round-reduced AES. Cryptology ePrint Archive, Paper 2017/832. 2017. [https://eprint.iacr.org/2017/832](https://eprint.iacr.org/2017/832)


`[5]` Navid Ghaedi Bardeh and Sondre Rønjom. The Exchange Attack: How to Distinguish Six Rounds of AES with $2^{88.2}$ chosen plaintexts. Cryptology ePrint Archive, Paper 2019/652. 2019. [https://eprint.iacr.org/2019/652](https://eprint.iacr.org/2019/652)



## Appendix

### A

Here is the full code of the challenge (you can also find it on the official repo of the
404CTF 2026 on Github [here](https://github.com/HackademINT/404CTF-2026/tree/main/Cryptanalyse))

The main code

```python
import hashlib
import copy
import os
import numpy as np
from Crypto.Random.random import choice

from consts import *


def b2s(b: bytes):
    """
    Convert a bytestring to a state
    """
    b = int.from_bytes(b, byteorder="big")
    s = GF2([(b >> (4 * i)) & 0x0F for i in reversed(range(16))])

    return s.reshape((4, 4))


def s2b(state: list[list[int]]):
    """
    Convert a state to a bytestring
    """
    b = b""
    for row in state:
        row_int = (
            (int(row[0]) << 12) | (int(row[1]) << 8) | (int(row[2]) << 4) | int(row[3])
        )

        b += row_int.to_bytes(2, byteorder="big")

    return b


def s2i(state: list[list[int]]):
    """
    Convert a state to an int
    """
    return int.from_bytes(s2b(state), byteorder="big")


def expand_key(k: bytes, r: int):
    ks = hashlib.shake_128(k).digest(r * len(k))
    return [ks[i : i + len(k)] for i in range(r)]


class State:
    def __init__(self, state: bytes):
        self.state = b2s(state)

    def round(self, key: bytes):
        self.state ^= b2s(key)
        self.state = S[self.state]
        self.state = np.matmul(P, self.state).transpose()
        self.state = np.matmul(M, self.state)

    def inv_round(self, key: bytes):
        self.state = np.matmul(M_inv, self.state)
        self.state = np.matmul(P.transpose(), self.state.transpose())
        self.state = S_inv[self.state]
        self.state ^= b2s(key)

    def last_round(self, key1: bytes, key2: bytes):
        self.state ^= b2s(key1)
        self.state = S[self.state]
        self.state = (P @ self.state).transpose()
        self.state ^= b2s(key2)

    def inv_last_round(self, key1: bytes, key2: bytes):
        self.state ^= b2s(key2)
        self.state = np.matmul(P.transpose(), self.state.transpose())
        self.state = S_inv[self.state]
        self.state ^= b2s(key1)

    def mix(self, rc: list[int]):
        mixed = GF64(s2i(self.state)) * GF64(rc[0]) + GF64(rc[1])
        self.state = b2s(int(mixed).to_bytes(64, byteorder="big"))

    def inv_mix(self, rc: list[int]):
        unmixed = (GF64(s2i(self.state)) - GF64(rc[1])) / GF64(rc[0])
        self.state = b2s(int(unmixed).to_bytes(64, byteorder="big"))

    def set_state(self, state: list[int]):
        self.state = GF2(state).reshape((4, 4))

    def to_bytes(self):
        return s2b(self.state)

    def get_nibble(self, i: int):
        return self.state[i // 4][i % 4]


class Cipher:
    ROUNDS = 9

    def __init__(self, key: bytes):
        self.keys = expand_key(key, self.ROUNDS)

    def encrypt_block(self, data: bytes):
        self.states = [State(data[:8]), State(data[8:])]

        self.quarter_round(0)
        self.permute(PI)
        self.transpose()
        self.round(1)
        self.permute(PI)
        self.transpose()
        self.round(3)
        self.permute(PI)
        self.transpose()
        self.round(5)
        self.permute(PI)
        self.transpose()
        self.last_round()

        return self.states[0].to_bytes() + self.states[1].to_bytes()

    def decrypt_block(self, data: bytes):
        self.states = [State(data[:8]), State(data[8:])]

        self.inv_last_round()
        self.transpose()
        self.permute(PI_inv)
        self.inv_round(5)
        self.transpose()
        self.permute(PI_inv)
        self.inv_round(3)
        self.transpose()
        self.permute(PI_inv)
        self.inv_round(1)
        self.transpose()
        self.permute(PI_inv)
        self.inv_quarter_round(0)

        return self.states[0].to_bytes() + self.states[1].to_bytes()

    def round(self, i: int):
        self.quarter_round(i)

        self.states[0].mix(RC[(i-1)//2])
        self.states[1].mix(RC[(i-1)//2])

        self.quarter_round(i + 1)

    def inv_round(self, i: int):
        self.inv_quarter_round(i + 1)

        self.states[0].inv_mix(RC[(i-1)//2])
        self.states[1].inv_mix(RC[(i-1)//2])

        self.inv_quarter_round(i)

    def last_round(self):
        rk0, rk1 = self.keys[-2][:8], self.keys[-2][8:]
        rk0_p, rk1_p = self.keys[-1][:8], self.keys[-1][8:]
        self.states[0].last_round(rk0, rk0_p)
        self.states[1].last_round(rk1, rk1_p)

    def inv_last_round(self):
        rk0, rk1 = self.keys[-2][:8], self.keys[-2][8:]
        rk0_p, rk1_p = self.keys[-1][:8], self.keys[-1][8:]
        self.states[0].inv_last_round(rk0, rk0_p)
        self.states[1].inv_last_round(rk1, rk1_p)

    def quarter_round(self, i: int):
        """
        Encrypt each state
        """
        rk0, rk1 = self.keys[i][:8], self.keys[i][8:]
        self.states[0].round(rk0)
        self.states[1].round(rk1)

    def inv_quarter_round(self, i: int):
        """
        Decrypt each state
        """
        rk0, rk1 = self.keys[i][:8], self.keys[i][8:]
        self.states[0].inv_round(rk0)
        self.states[1].inv_round(rk1)

    def permute(self, perm: list[int]):
        """
        Mixing layer
        """
        new_states = [[None for _ in range(16)] for _ in range(2)]

        for i, pi in enumerate(perm):
            new_states[i // 16][i % 16] = self.states[pi // 16].get_nibble(pi % 16)

        self.states[0].set_state(new_states[0])
        self.states[1].set_state(new_states[1])

    def transpose(self):
        self.states[0].state = self.states[0].state.transpose()
        self.states[1].state = self.states[1].state.transpose()


if __name__ == "__main__":
    for _ in range(64):
        k = os.urandom(16)
        cipher = Cipher(k)

        is_cipher = choice((False, True))

        queried_pt = {}
        queried_ct = {}

        for _ in range(4):
            action = int(input("What should I do ?\n [1] encrypt\n [2] decrypt\n>>> "))

            response = None

            if action == 1:
                pt = bytes.fromhex(input(">>> "))
                
                assert len(pt) == 16

                if pt in queried_pt:
                    response = queried_pt[pt]
                else:
                    ct_cipher = cipher.encrypt_block(pt)
                    ct_random = os.urandom(len(ct_cipher))

                    if is_cipher:
                        response = ct_cipher
                    else:
                        response = ct_random

                    queried_pt[pt] = response
                    queried_ct[response] = pt

            elif action == 2:
                ct = bytes.fromhex(input(">>> "))

                assert len(ct) == 16

                if ct in queried_ct:
                    response = queried_ct[ct]
                else:
                    pt_cipher = cipher.decrypt_block(ct)
                    pt_random = os.urandom(len(pt_cipher))

                    if is_cipher:
                        response = pt_cipher
                    else:
                        response = pt_random

                    queried_ct[ct] = response
                    queried_pt[response] = ct
            else:
                exit(1234)

            print("Result", response.hex())

        print("Time to make a guess !")
        guess = input("Random/Cipher\n>>> ")

        if guess not in ["Cipher", "Random"] or (guess == "Cipher") ^ is_cipher:
            print("Nope...")
            exit(1337)

    print(f'Congratz !\n{os.getenv("FLAG", "404ctf{flag_placeholder}")}')
```

The constants defined in another script :

```python
import galois

GF2 = galois.GF(
    2**4,
    primitive_element="x",
    irreducible_poly="x^4 + x + 1"
)

GF64 = galois.GF(
    2**64,
    primitive_element="x",
    irreducible_poly="""
x^64 + x^33 + x^30 + x^26 + 
x^25 + x^24 + x^23 + x^22 + 
x^21 + x^20 + x^18 + x^13 + 
x^12 + x^11 + x^10 + x^7 + 
x^5 + x^4 + x^2 + x + 1""".replace("\n", ""),
)

S = GF2([
    0xC, 0x5, 0x6, 0xB,
    0x9, 0x0, 0xA, 0xD,
    0x3, 0xE, 0xF, 0x8,
    0x4, 0x7, 0x1, 0x2
])

S_inv = GF2([
    0x5, 0xe, 0xf, 0x8,
    0xc, 0x1, 0x2, 0xd,
    0xb, 0x4, 0x6, 0x3,
    0x0, 0x7, 0x9, 0xa,
])

M = GF2([
    [0xd, 0x7, 0xa, 0x3],
    [0x7, 0xd, 0x3, 0xa],
    [0xa, 0x3, 0xd, 0x7],
    [0x3, 0xa, 0x7, 0xd],
])

M_inv = GF2([
    [0x6, 0x4, 0x2, 0xe],
    [0x4, 0x6, 0xe, 0x2],
    [0x2, 0xe, 0x6, 0x4],
    [0xe, 0x2, 0x4, 0x6]
])

P = GF2([
        [0, 1, 0, 0],
        [0, 0, 0, 1],
        [1, 0, 0, 0],
        [0, 0, 1, 0],
])

PI = [
    0x00, 0x04, 0x08, 0x0c,
    0x10, 0x14, 0x18, 0x1c,
    0x12, 0x16, 0x1a, 0x1e,
    0x02, 0x06, 0x0a, 0x0e,
    0x01, 0x05, 0x09, 0x0d,
    0x11, 0x15, 0x19, 0x1d, 
    0x13, 0x17, 0x1b, 0x1f,
    0x03, 0x07, 0x0b, 0x0f,
]

PI_inv = [
    0x00, 0x10, 0x0c, 0x1c,
    0x01, 0x11, 0x0d, 0x1d,
    0x02, 0x12, 0x0e, 0x1e,
    0x03, 0x13, 0x0f, 0x1f,
    0x04, 0x14, 0x08, 0x18,
    0x05, 0x15, 0x09, 0x19,
    0x06, 0x16, 0x0a, 0x1a,
    0x07, 0x17, 0x0b, 0x1b,
]

RC = GF64(
    [
        (15563547985028666209, 17373446690097110111),
        (11180344970179797439, 15565830289949094619),
        (17159356484676438073, 14015056423472729382),
        (12973532568921255953, 17681326978715781984),
        (14451483335712091177, 11223639765572704747),
        (13832203440798053431, 11853827721303106934),
    ]
)
```