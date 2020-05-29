### Simple Vagrant project that creates Windows 2016 adds AD DS after that promotes the server to DC.

```bash
vagrant up
```

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.56.2
```

```bash
vagrant destroy -f
```

## References

https://www.iana.org/assignments/kerberos-parameters/kerberos-parameters.xhtml

https://web.mit.edu/kerberos/krb5-latest/doc/admin/conf_files/krb5_conf.html

https://web.mit.edu/kerberos/kfw-4.1/kfw-4.1/kfw-4.1-help/html/encryption_types.htm

https://imatviyenko.github.io/blog/2018/09/11/Apache-AD-kerberos
