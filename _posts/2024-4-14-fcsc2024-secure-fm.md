---
layout: post
title: Secure FM
tags: Write-up 2024 hardware radio-frequencies fm fhss FCSC fcsc
---
![meme](assets/img/antenna.jpeg)
# Category
Hardware

# Description
> Dans votre laboratoire, un vieux briscard vous explique qu'il n'y a pas besoin de cryptographie pour protéger un signal radio et que le saut de fréquence rapide est incassable. Qu'en dîtes vous ?
>
> Vous avez à votre disposition un graphe GNURadio et le signal résultant.

> Files :
> *secure-fm.iq.tar.xf*
# Solution

I have the graphflow of the GNURadio software that encrypt the communication and the iq file of the output. I considered two ways to potentially solve it.
The first one is to recover the noise using a known plaintext attack (using the file mobydick.txt which may be the one I found on github), retrieve the state of the PRNG used (which might be possible because it seems that it uses something like XORShift128+) and then decrypt the entire file. However, it seems maybe a bit too complicated and assumes that the file (or at least the start of the file) encrypted is indeed the one I found online.
The other solution it to think a bit more and realise something very important : the frequency shift created by the [FHSS](https://en.wikipedia.org/wiki/Frequency-hopping_spread_spectrum) is sufficiently important to allow us to distinguish which channel is used. In fact, we have a potential carrier every each `2k+1` kHz while the data can take the values of `c-750Hz,c-250Hz,c+250Hz,c+750Hz` where `c` is the carrier. So for every frequency observed, I am able to find the unique carrier (which is the nearest one in term of frequency) and then decode the message.


The first thing to do is to load our IQ file which has the format : float32:float32:...:float32 and define some constants
```python
import numpy as np
import sys
import matplotlib.pyplot as plt

samples = np.fromfile(sys.argv[1], dtype="complex64")

F_E = 32e3		# sampling frequency
T_E = 1/F_E		# sampling rate
T_S = 1e3*T_E	# Duration of one symbol
N_fft = 2048	# Number of FFT
P_S = 10**3 	# Number of sampes per symbol

VALUES = [ c+m for c in range(-15000,15000+1,2000) for m in range(-750,750+1,500)]	# Value that can be taken by the signal
C = [c for c in range(-15000,15000+1,2000)]											# The values of the carriers
SYMB = {																			# Signal deviation from carrier for each symbol
  -750:0,
  -250:1,
  250:2,
  750:3
}
```

Now that we have loaded our signal and defined some constants, the next step is to perform a [discrete-time Fourier transform](https://en.wikipedia.org/wiki/Discrete-time_Fourier_transform) and round the obtained frequencies to the possible values of the signal.
```python
def round(v,L = VALUES):			# given a value, this function will round the value to the nearest element of the list L
	best_approx = 0
	dist = np.abs(L[0]-v)
	for i in range(1,len(L)):
		d = np.abs(L[i]-v)
		if d < dist:
			dist = d
			best_approx = i
	return dist,L[best_approx]

def get_carry(f):					# To get the carrier, it's as simple as round the value to the nearest possible carrier
	return round(f,L=C)[1]			# Return only the carrier because have to error is useless

def get_value(window):
  fft_cal = np.fft.fft(window,N_fft)					# Compute the DTFT of the signal of a unique symbol
  freqs = np.fft.fftfreq(N_fft,T_E)						# Determine the frequencies obtained with the DTFT
  fft_calc_pos = np.abs(fft_cal[:N_fft//2])				# Get the DTFT positive frequencies
  fft_calc_neg = np.abs(fft_cal[N_fft//2:])				# Get the DTFT negative frequencies
  freqs_pos = freqs[:N_fft//2]							# Get the corresponding positive frequencies
  freqs_neg = freqs[N_fft//2:]							# Get the corresponding negative frequencies
  m_freq_pos = freqs_pos[np.argmax(fft_calc_pos)]		# Obtain the positive frequency that has the amplitude 
  m_freq_neg = freqs_neg[np.argmax(fft_calc_neg)]		# Obtain the negative frequency that has the amplitude 
  dist_neg,rounded_m_freq_neg = round(m_freq_neg)		# Compute the nearset negative valid frequency and the error commited
  dist_pos,rounded_m_freq_pos = round(m_freq_pos)		# Compute the nearset positive valid frequency and the error commited
  
  if dist_neg<dist_pos:									# If the more accurate approximation is the approx made on the negative frequency
  	c = get_carry(rounded_m_freq_neg)					# Get the corresponding carrier
  	value = rounded_m_freq_neg-c						# Substract the carrier and return the result
  	return value
  c = get_carry(rounded_m_freq_pos)						# Else, the more accurate one is the approx made on positive frequency
  value = -(c-rounded_m_freq_pos)
  return value 											# Return the frequency minus the obtained carrier
```

So, I have loaded the IQ file, declared some constants, and now I can also get the "real" frequency of the signal (without the FHSS) for a given symbol.

*Note : I try to get one positive and one negative value because I encounter sometimes some approximation problems, so trying to get a positive and a negative frequency (even if sometimes both channel are on a positive/negative carrier) help me to get better results*

Now I have to apply this function on every symbols of the IQ file :
```python
symbols = []
for i in range(0,len(signal),3*P_S):								# A unique symbol experiences 3 differents frequency jumps
	values = []														# The values recovered of the symbol for each frequency jump
	for j in range(0,3*P_S,P_S):									# Each frequency jump has a duration of T_S, which consists in T_S/T_E elements in the list
		values.append(get_value(signal[i+j:i+j+P_S]))				# Get the value of the symbol using the function coded above
	val, counts = np.unique(values, return_counts=True)				# Get the most repeated value from our extracted symbols
	ind = np.argmax(counts)
	symbols.append(SYMB[val[ind]])									# Convert it to an int between [0,3]
```

The last thing remaining is to convert the obtained symbols to a printable string :
```python
def to_byte(symbols):											# Each symbol contain 2 bits of information, I need 4 symbols to get a byte
  return sum([symbols[i//2]*2**(6-i) for i in range(0,8,2)])	# Convert an array of 4 symbols to an int between [0,255]

def symbols2str(symbols):										# Convert a list of symbols to a list of printable string
  s = ""
  for i in range(0,len(symbols),4):								# Get the corresponding byte of four symbol
    s+=chr(to_byte(symbols[i:i+4]))								# Append the obtained character to the string
  return s 														# Return the string
```

Then to decode the retrieved symbols :
```python
with open('decoded.txt','w+') as f:
	f.write(symbols2str(symbols))
```

And there is the flag !!!
```
CALL me Ishmael. Some years ago never mind how 
long precisely having little or no money in my purse, 
and nothing particular to interest me on shore, I thought 
I would sail about a little and see the watery part of the 
world. It is a way I have of driving off the spleen, and 
regulating the circulation. Whenever I find myself 
growing grim about the mouth ; whenever it is a damp, 
drizzly November in my soul ; whenever I find myself 
involuntarily pausing before coffin warehouses, and bring- 
ing up the rear of every funeral I meet ; and especially 
whenever my hypos get such an upper hand of me, that 
it requires a strong moral principle to prevent me from 
deliberately stepping into the street, and methodically 
knocking people's hats off then, I account it high time 
to get to sea as soon as I can. This is my substitute for 
pistol and ball. With a philosophical flourish Cato throws 
himself upon his sword ; I quietly take to the ship. 
There is nothing surprising in this. If they but knew 
it, almost all men in their degree, some time or other, 
cherish very nearly the same feelings toward the ocean 
with me. 

There now is your insular city of the Manhattoes, 
belted round by wharves as Indian isles by coral reefs 
commerce surrounds it with her surf. Right and left, the 
streets take you waterward. Its extreme down -town is the 
battery, where that noble mole is washed by waves, and 
cooled by breezes, which a few hours previous were out of 
sight of land. Look at the crowds of water -gazers there. 

Circumambulate the city of a dreamy Sabbath after- 
noon. Go from Corlears Hook to Coenties Slip, and 
from thence, by Whitehall, northward. What do you 
see ? Posted like silent sentinels all around the town, 
stand thousands upon thousands of mortal men fixed 
in ocean reveries. Some leaning against the spiles ; 
some seated upon the pier-heads ; some looking over 
Vhe bulwarks of ships from China ; some high aloft in 
the rigging, as if striving to get a still better seaward 
peep. But these are all landsmen ; of week days pent 
up in lath and plaster tied to counters, nailed to benches, 
clinched to desks. How then is this ? Are the green 
fields gone ? What do they here ? 

FCSC{45157c712a46090d497ce258eb534167194910ae3edbf988c0afca8c0a0bef29}

But look ! here come more crowds, pacing straight for 
the water, and seemingly bound for a dive. Strange ! 
Nothing will content them but the extremest limit of the 
land ; loitering under the shady lee of yonder warehouses 
will not suffice. No. They must get just as nigh the 
water as they possibly can without falling in. And there 
they stand miles of them leagues. Inlanders all, they 
come from lanes and alleys, streets and avenues north, 
east, south, and west. Yet here they all unite. Tell me, 
does the magnetic virtue of the needles of the compasses 
of all those ships attract them thither ? 

Once more. Say, you are in the country ; in some 
high land of lakes. Take almost any path you please, 
and ten to one it carries you down in a dale, and leaves 
you there by a pool in the stream. There is magic in it. 
Let the most absent-minded of men be plunged in his 
deepest reveries stand that man on his legs, set his feet 
a-going, and he will infallibly lead you to water, if water 
there be in all that region. Should you ever be athirst 
in the great American desert, try this experiment, if your 
caravan happen to be supplied with a metaphysical 
professor. Yes, as everyone knows, meditation andli 
water are wedded forever. 

But here is an artist. He desires to paint you the 
dreamiest, shadiest, quietest, most enchanting bit of 
romantic landscape in all the valley of the Saco. What 
is the chief element he employs ? There stand his trees, 
each with a hollow trunk, as if a hermit and a crucifix 
were within ; and here sleeps his meadow, and there sleep 
his cattle ; and up from yonder cottage goes a sleepy 
smoke. Deep into distant woodlands winds a mazy way, 
reaching to overlapping spurs of mountains bathed in 
their hillside blue. But though the picture lies thus 
tranced, and though this pine-tree shakes down its sighs 
like leaves upon this shepherd's head, yet all were 
vain, unless the shepherd's eye were fixed upon the 
magic stream before him. Go visit the Prairies in June, 
when for scores on scores of miles you wade knee -deep 
among tiger-lilies what is the one charm wanting ?- 
Water there is not a drop of water there ! Were Niagara 
but a cataract of sand, would you travel your thousand 
miles to see it ? Why did the poor poet of Tennessee, 
upon suddenly receiving two handfuls of silver, deliberate 
whether to buy him a coat, which he sadly needed, or 
invest his money in a pedestrian trip to Rockaway Beach ? 
Why is almost every robust healthy boy with a robust 
healthy soul in him, at some time or other crazy to go to 
sea ? Why upon your first voyage as a passenger, did 
you yourself feel such a mystical vibration, when first ; 
told that you and your ship were now out of sight of ' 
land ? Why did the old Persians hold the sea holy ? 
Why did the Greeks give it a separate deity, and own 
brother of Jove ? Surely all this is not without meaning. 
```

Flag : `FCSC{45157c712a46090d497ce258eb534167194910ae3edbf988c0afca8c0a0bef29}`
***
*Write-up author : acmo0