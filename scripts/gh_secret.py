#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通过 GitHub REST API 设置仓库 Actions Secret。
Secret 值需用仓库的公钥做 Curve25519 加密（libsodium SealedBox），
因此必须安装 pynacl:  pip install pynacl

用法:
  python gh_secret.py <PAT> <OWNER> <REPO> <NAME> <VALUE>
"""
import sys
import base64
import requests

try:
    from nacl.public import PublicKey, SealedBox
except ImportError:
    sys.exit("❌ 需要 pynacl，请先: pip install pynacl")


def set_secret(pat: str, owner: str, repo: str, name: str, value: str):
    headers = {
        "Authorization": f"token {pat}",
        "Accept": "application/vnd.github+json",
    }
    # 1. 取仓库公钥
    r = requests.get(
        f"https://api.github.com/repos/{owner}/{repo}/actions/secrets/public-key",
        headers=headers,
        timeout=15,
    )
    r.raise_for_status()
    pk = r.json()

    # 2. 用公钥加密
    public_key = PublicKey(base64.b64decode(pk["key"]))
    sealed = SealedBox(public_key).encrypt(value.encode("utf-8"))
    encrypted = base64.b64encode(sealed).decode("ascii")

    # 3. 写入 secret
    body = {"encrypted_value": encrypted, "key_id": pk["key_id"]}
    r2 = requests.put(
        f"https://api.github.com/repos/{owner}/{repo}/actions/secrets/{name}",
        headers=headers,
        json=body,
        timeout=15,
    )
    r2.raise_for_status()
    print(f"✅ secret [{name}] 已写入 {owner}/{repo}")


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit("用法: python gh_secret.py <PAT> <OWNER> <REPO> <NAME> <VALUE>")
    set_secret(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
