// ─────────────────────────────────────────────────────────────────────────────
// ISRG Root X2（Let's Encrypt 的新根证书，ECDSA P-384，2020 年生成，2040 年到期）
// ─────────────────────────────────────────────────────────────────────────────
// 为什么要在 Android 客户端注入这张证书？
//
//   Dart HttpClient 在 Android 上**不**走 Android 系统的 trust store，
//   而是用 dart:io 自己内置的 BoringSSL + Mozilla NSS root CA bundle。
//   Flutter SDK 不同版本嵌入的 NSS bundle 时间不同，老一些的版本
//   可能缺 ISRG Root X2。
//
//   Let's Encrypt 当前用 E5–E9 这一组 **ECDSA 中级证书** 签发新证书，
//   而 E 系列是被 ISRG Root X2 签名的。一旦 LE 把交叉签名链
//   （E* → ISRG Root X1）撤掉，所有只信任 X1 的客户端都会 handshake 失败。
//
//   嵌入 X2 是廉价的防御：只要客户端 trust store 同时持有 X1+X2，
//   不管 LE 走哪条链路，TLS 验证都能成功。
//
// 参考：https://letsencrypt.org/certificates/
// ─────────────────────────────────────────────────────────────────────────────
// ignore: constant_identifier_names
const String ISRG_X2 = """-----BEGIN CERTIFICATE-----
MIICGzCCAaGgAwIBAgIQQdKd0XLq7qeAwSxs6S+HUjAKBggqhkjOPQQDAzBPMQsw
CQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFyY2gg
R3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMjAeFw0yMDA5MDQwMDAwMDBaFw00
MDA5MTcxNjAwMDBaME8xCzAJBgNVBAYTAlVTMSkwJwYDVQQKEyBJbnRlcm5ldCBT
ZWN1cml0eSBSZXNlYXJjaCBHcm91cDEVMBMGA1UEAxMMSVNSRyBSb290IFgyMHYw
EAYHKoZIzj0CAQYFK4EEACIDYgAEzZvVn4CDCuwJSvMWSj5cz3es3mcFDR0HttwW
+1qLFNvicWDEukWVEYmO6gbf9yoWHKS5xcUy4APgHoIYOIvXRdgKam7mAHf7AlF9
ItgKbppbd9/w+kHsOdx1ymgHDB/qo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0T
AQH/BAUwAwEB/zAdBgNVHQ4EFgQUfEKWrt5LSDv6kviejM9ti6lyN5UwCgYIKoZI
zj0EAwMDaAAwZQIwe3lORlCEwkSHRhtFcP9Ymd70/aTSVaYgLXTWNLxBo1BfASdW
tL4ndQavEi51mI38AgEh06WhfVTLcGXFnxr1IZL2VPj8GdSPgdNXc+wnEhDb+oP3
-----END CERTIFICATE-----""";
