---
layout: post
title: Lookup
subtitle: A hardware challenge from FCSC
tags: Write-up FCSC 2026 hardware radio-frequencies
---

# Lookup

> There is two challs named lookup, the first one is `Lookup: From the skies`, the second one is `Lookup: Past future`. They are both handled in this post


## From the skies

**Description (fr)**

> Les communications satellites ne sont pas mystiques. Avant le DVB-S2, un premier standard existait. Pour commencer, voilà un signal en bande de base, échantillonné à un échantillon par symbole.  Retrouverez-vous la vidéo transportée ?  La capture est au format IQ, avec chaque composante étant un float32.


**Solve**
After some quick search (mainly wikipedia), I learnt that the standard before DVB-S2 was DVB-S, which seems quite coherent.
This standard allows to transport MPEG frames (wich may contain audio, video and subtitles) using radio-frequences.

Because the difficulty of this challenge is "medium", I first tried to find some tools to process automatically the file and retrieve the video. I quickly found to the [leansdr](https://github.com/pabr/leansdr) tools package which contains a tool called `leandvb` which does exactly what I want.


After setting the sample rate at the same value of the symbol rate as it was explained in the challenge's description I was able to retrieve the first video :
```
./leandvb --sr 2.4e6 --gui --f32 < lookup.iq | vlc -
```
> (`--f32` means that the samples are float32 numbers)

Thank to that video... I had a new video to decode at https://files.fcsc.fr/261e56bb-5a19-8ea4-a9e6-d12512bc54cf

![meme1](/assets/img/lookup_meme1.jpg)


So, here we go for the next noisy IQ file. The chall maker was cool and give us some precious information : the coding rate is 3/4 (standard one is 1/2), the signal is not a baseband signal anymore and moreover there is some noise added to it...

![meme2](/assets/img/lookup_meme2.jpg)

To decode the video, I have to :

- retrieve the central frequency of the signal to shift it back to baseband signal : I did it graphicaly using GQRX
- find the right options for leandvb to filter the noise
- find the right options to also decode using the 3/4 coding rate
- find how many samples there is for one symbol


I tried first : `./leandvb  -f 24e5 --sr 24e5  --f32 --cr 3/4 --tune 370e3 --gui` but the decoded symbols weren't coherent so I tried various symbols rate 12e5 and then 8e5 which was the right one. I also noticed that leansdr allows to try various arguments automatically but since I quickly found the right ones I did not use that feature. 

However, since there is too much noise, of course the Software Defined Radio (SDR) was not able to retrieve the frames. 

I finaly found out that using the virterbi decoder was the right thing to do to retrieve the video :
```
leandvb -f 24e5 --sr 8e5  --f32 --cr 3/4 --tune 370e3 --gui --hard-metric --viterbi < noisy.iq | vlc -
```

The flag for this first step is `FCSC_Lookuptotheskies_876e0d1617fc004a207f765f996fbe2`

## Past Future

> Il existe un standard entre le DVB-S et le DVB-S2 du doux nom de DVB-DSNG. Voilà un nouveau signal en bande de base, à un échantillon par symbole.  Retrouverez-vous la vidéo transportée ?  La capture est au format IQ, avec chaque composante étant un float32.

![meme3](/assets/img/lookup_meme3.jpg)

After some search on internet, I found the specs about both DVB-S and DVB-DSNG. Here is the block diagram of a DVB-DSNG emitter :

![DSNG block diagram](/assets/img/lookup_dsng_bd.png)

> From EN 301 210 - v01.01.01 (DVB-DSNG spec)


One of the first thing that caught my attention was the fact that DVB-DSNG standard when symbols are mapped to a QPSK constellation is completely compatible with DVB-S. Of course in our case the samples are mapped to a 8PSK contellation... This can be seen easily using GNU Radio of even by reading the IQ samples. For example with python :

```python
import numpy as np
import matplotlib.pyplot as plt

# I = float32, Q = float32 => complex64
iq = np.fromfile('chall.iq', np.complex64)

plt.scatter(np.real(iq[:100]), np.imag(iq[:100]))
plt.show()
```

Which outputs :
![8PSK plotted](/assets/img/lookup_8psk.png)

However, there is a way to "cheese" a bit the whole decoding process. In fact, one can decode the 8PSK symbols, retrieve the bytestream before the convolutionnal encoder and then re-encode everything in QPSK to decode it using her favourite SDR.


Because I am a bit lazy, I first tried the 2/3 coding rate with 8PSK. I lost a lot of time because I tried with various parameters (like the bit ordering for example). After lossing some time with the 2/3 coding rate, I did exactly the same with the  5/6 coding rate. I finaly admit that the chall makers choosed the scariest coding rate : 8/9 with 8PSK :)
Note that according to the spec, there were a way for me to decide wether or not my decoding was right : I should retrieve regularly the sync byte of MPEG frame when decoding all that stuff (accoding to the spec).

**Demodulate the 8PSK**

Here is the constellation used by the 5/6 and 8/9 8PSK encoders :

![8PSK constellation](/assets/img/lookup_8psk_const.png)

> From EN 301 210 - v01.01.01 (DVB-DSNG spec)

This can be implemented efficiently (but the code is a bit awful) using numpy :
```python
A = np.cos(np.pi/8)
B = np.sin(np.pi/8)

def psk_demod(samples: np.array):
	u2 = (np.imag(samples) < 0).astype(np.uint8)
	u1 = (np.imag(samples) * np.real(samples) < 0).astype(np.uint8)
	c1 = ((np.abs(samples - (B + A*1j))  < 1e-5) | (np.abs(samples - (-A +B*1j))  < 1e-5) | (np.abs(samples - (-B - A*1j))  < 1e-5) |( np.abs(samples - (A - B * 1j)) < 1e-5)).astype(np.uint8)

	return u2, u1, c1
```

**Decode the encoded byte**

Here is how the byte stream is encoded :

![Inner coding](/assets/img/lookup_inner_coding.png)

The idea is the following : you have a bytestream `ABDFABDF...`. Each `A` byte will be encoded in the convolutional encoder, the others remain unchanged. From two bits of `A`, the encoder will output four bits : *X1*, *Y1*, *X2*, *Y2* and at the output of the puncturing block only *X1*, *Y1* and *Y2* will be transmitted.

Using the viterbi python module, one can retrieve two bits of `A` from *X1*, *Y1* and *Y2* in the following way :

```python
from viterbi import Viterbi

# puncting : X1, Y1, X2, Y2 => X1, Y1, Y2
puncture_pattern = [1, 1, 0, 1]
# The two poly are from the spec (see Table2 at page 11)
v = Viterbi(7, [0o171, 0o133], puncture_pattern) 

decoded = v.decode([x1, y1, y2])
```

Two retrieve the decoded bytes, we have to know how the parallel bitstreams of the encoding of `A` and the remaining bytes are mixed together to form symbols which will be 8PSK-mapped.

The table 3 of the spec (page 14) gives such information. We can de-interleave the bits to retrieve the "original" bytes (note that the encoded bits of `A` are transmitted in the "right" order, no need to deinterleave them) :

```python3
import numpy as np
from viterbi import Viterbi

iq = np.fromfile("chall.iq", np.complex64)

# c.f previous code sample
u2, u1, c1 = psk_demod(iq)


puncture_pattern = [1, 1, 0, 1]
v = Viterbi(7, [0o171, 0o133], puncture_pattern)

# Takes a bit of time and RAM :)
decoded_bits = v.decode(c1)

###########

# Deinterleave

# First alternate bits from U2 and U1
unencoded_bits = np.empty(len(u2)*2, dtype=np.uint8)
unencoded_bits[0::2] = u2
unencoded_bits[1::2] = u1

# deinterleave the bitstream
b_bits = np.empty(len(unencoded_bits)//3, dtype=np.uint8)
d_bits = np.empty(len(unencoded_bits)//3, dtype=np.uint8)
f_bits = np.empty(len(unencoded_bits)//3, dtype=np.uint8)

# (maybe not the fancier way to do this)
# B is fully transmitted
for i in range(8):
	b_bits[i::8] = unencoded_bits[i::24]

# Then the 4th first bits of D
for i in range(4):
	d_bits[i::8] = unencoded_bits[8+i::24]

# then the 2d first bits of F 
for i in range(2):
	f_bits[i::8] = unencoded_bits[12+i::24]

# Remaining bits of D
for i in range(4):
	d_bits[4+i::8] = unencoded_bits[14+i::24]

# The remaining part is the bits of F
for i in range(6):
	f_bits[2+i::8] = unencoded_bits[18+i::24]
```

Now we have the bitstream of each byte, we can pack the bitstream to retrieve the bytes and put them together in the right order of transmission (A, then B, then D and then F) :

```python
a_bytes = np.packbits(decoded_bits)
b_bytes = np.packbits(b_bits)
d_bytes = np.packbits(d_bits)
f_bytes = np.packbits(f_bits)

decoded_bytes = np.empty(len(decoded_bits)//8 * 4, dtype=np.uint8)

decoded_bytes[0::4] = np.packbits(decoded_bits)
decoded_bytes[1::4] = b_bytes
decoded_bytes[2::4] = d_bytes
decoded_bytes[3::4] = f_bytes
```

Now that we retrieved the bytestream before all that interleaving/encoding stuff, we can re-encode them and modulate them in QPSK !

This time we can simply put the bytestream in the convolutional encoder (without puncturing), pack the result to obtain the symbols and map them to the QPSK constellation.

```python
# Mapping table
QPSK_TABLE = np.array([
	1 + 1j, 1 + -1j, -1 + 1j,-1 - 1j
]).astype(np.complex64)

# bytestream -> bitstream
to_encode = np.unpackbits(decoded_bytes)
v = Viterbi(7, [0o171, 0o133])

encoded_bits = np.array(v.encode(to_encode), dtype=np.uint8)

# QPSK = 2 bits per symbol
# group bits by two
# reverse each group of two (bc of the bitorder of numpy.packbits)
# pack each group of bits
# flatten the result
symbols = np.packbits(encoded_bits.reshape(len(encoded_bits)//2, 2)[:,::-1], axis=1, bitorder="little").flatten()

modulated = QPSK_TABLE[symbols]

# Write that to a file
modulated.tofile("re-modulated.iq")
```

Now that we have re-encoded and modulated everything in a compatible way for DVB-S standard, I can do exactly the same as for the first part of that challenge using leandvb :
```
./leandvb --sr 2.4e6 --gui --f32 < re-modulated.iq | vlc -
```

We can now watch the video and retrieve the flag : `FCSC_DsngIsTheFutureOfThePast_e14c24c76ca11b22a973d978f99c9d8d`

> Note : It would be more educational to do the full decoding of DSNG, but I think that the way I did was more efficient.