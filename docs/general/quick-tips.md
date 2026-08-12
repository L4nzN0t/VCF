_Grab certificate of appliance_
```
[Windows]
openssl s_client -showcerts -connect domain 2>$null | openssl x509 -outform PEM > cert.cer
```

_Reset password vcf user SDDC Manager/VCF Installer_
```
faillock --user vcf --reset
```

_Default offline depot folder_
```
/DEPOT/
```

_Check correct folder for VCF components_
```
kubectl get pd vmsp-platform -n vmsp-platform -o jsonpath='{.spec.values.provider.vsphere}' | jq | grep  folder
```
_Erase password history root user in vCenter_
```
echo “” >/etc/security/opasswd then the passwd command
```

_Reset NSX Manager root password_
```
1. Connect to the console of the appliance.
2. Reboot the system.
3. When the GRUB boot menu appears, press the left SHIFT or ESC key quickly. If you wait too long and the boot sequence does not pause, you must reboot the system again.
4. Press e to edit the menu.
Choose the top Ubuntu line then enter the user name root and the GRUB password for root (not the same as the appliance's user root). The default password is NSX@VM!WaR10.
5. Press e to edit the selected option.
6. Search for the line starting with linux and add systemd.wants=PasswordRecovery.service to the end of the line.
7. Press Ctrl-X to boot.
8. When the log messages stop, enter the new password for root.
9. Enter the password again.
The boot process continues.
10. After the reboot, you can verify the password change by logging in as root with the new password.
```
_Syncronize NSX password across the nodes_
```
/etc/init.d/nsx-mp-api-server stop
passwd root
touch /var/vmware/nsx/reset_cluster_credentials
/etc/init.d/nsx-mp-api-server start
set auth-policy api lockout-period 0
set auth-policy api lockout-reset-period 0
set auth-policy api max-auth-failures 0

** To check if the password is changed:
chage -l root

https://knowledge.broadcom.com/external/article/317192/nsx-credentials-are-not-being-synchroniz.html
```
