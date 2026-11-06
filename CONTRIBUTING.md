# Contributing

PRs are welcome for smaller images, stable HomeProxy / sing-box-tiny compatibility, improved build repeatability, and AX6 device testing.

Please include:

1. Your baseline vs modified image sizes, with `*.manifest` and upstream source SHA.
2. A concise description of changed `.config`, build flags, scripts, or package dependencies.
3. Real-hardware validation for network / Wi-Fi / NAT / HomeProxy / VLESS Reality / Shadowsocks where applicable.
4. An explicit statement if the change requires an expanded MTD / UBI layout. Such changes should **not** be silently merged into the `redmi_ax6-stock` recipe.

Never upload personal VPN credentials, calibration partitions, or other device secrets.
