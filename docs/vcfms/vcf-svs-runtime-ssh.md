### SSH to VCF Runtime Services

1. Log in to the VCF Operations interface at https://<vcf_operations_fqdn> as a user assigned the Administrator role.

2. Navigate to **Build > Lifecycle > VCF Management.**

3. On the Components tab, select the VCF services runtime.
Scroll to the Nodes section.

4. Identify a control plane node and note the IP address.

Using the IP address, open an SSH connection to the control plane node as the vmware-system-user using the APPLIANCE_ROOT_PASSWORD.

To obtain administrative access to the control plane, enter the following commands.
```
sudo -i
export KUBECONFIG=/etc/kubernetes/admin.conf
```

To confirm that you have logged in to a control plane node, enter the following command.
```
kubectl get nodes -o wide
```
_______________________________________________________

To access the services
```
kubectl get pods -A
```

#### List of namespaces
kube-system
salt-raas
salt
telemetry
vcf-fleet-depot
vcf-fleet-lcm
vcf-sddc-lcm
vidb-external
vmsp-platform

depot-service - Pod to check fleet mgmt components being downloaded in VCF Ops 9.1

_______________________________________________________

#### Reference

https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/fleet-management/configuring-management-components/enable-ssh-access-to-the-vcf-services-runtime-cluster.html
