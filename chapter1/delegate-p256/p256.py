import sys
import subprocess

args = sys.argv[1:]
if args[0] == "gen":
    subprocess.run(
        "openssl ecparam -name prime256v1 -genkey -noout -out private.pem",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        "openssl ec -in private.pem -pubout -out public.pem",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    data = (
        subprocess.check_output(
            "openssl ec -in private.pem -text", shell=True, stderr=subprocess.DEVNULL
        )
        .decode()
        .rstrip()
        .replace("\n", "")
        .replace(" ", "")
    )
    priv = data.split("priv:")[1].split("pub:")[0].replace(":", "")
    pub = data.split("pub:")[1].split("ASN1")[0].replace(":", "")[2:]
    pub_x, pub_y = pub[:64], pub[64:]

    print(f"Private key: 0x{priv}")
    print(f"Public key: 0x{pub_x}, 0x{pub_y}")
elif args[0] == "sign":
    payload = bytearray.fromhex(args[1].replace("0x", ""))

    proc = subprocess.Popen(
        ["openssl", "dgst", "-keccak-256", "-sign", "private.pem"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    output = proc.communicate(payload)[0]
    proc = subprocess.Popen(
        ["openssl", "asn1parse", "-inform", "DER"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    output = proc.communicate(output)[0].decode().replace(" ", "").replace("\n", "")

    sig_r = output.split("INTEGER:")[1][:64]
    sig_s = output.split("INTEGER:")[2][:64]

    print(f"Signature r: 0x{sig_r}")
    print(f"Signature s: 0x{sig_s}")
