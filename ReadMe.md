# ClickOS Setup Guide
## Uses Xen & Ubuntu 16.04

This has been tested on a real machine and in a virtualbox VM with Ubuntu Server 16.04.5 (downloaded from [here](http://releases.ubuntu.com/16.04/))

## Installation (inc VM instructions)

* Install VirtualBox and its requirements on your machine
* Create a VM giving at least 4GB of RAM and 4 CPU cores (or the install may take a very long time)
* Change the adapter type in VirtualBox to Intel PRO/1000 MT Server and enable ssh port forwarding (e.g. Host Port 2222, Guest Port 22)
* Boot using the Ubuntu Server ISO and install however you desire (internet access is required on the VM)
* Once Ubuntu is installed, clone this repository into a directory, and make sure to be root
* Make the "setup.sh" executable (chmod +x ./setup.sh)
* Run "setup.sh" (Can take quite a while to run)
* When asked for the number of make jobs, enter a number up to the number of given cpu cores (the more the better)
* Follow the insturctions given by the script
* Once rebooted, the machine should be setup with a few unikernel platforms cloned into the dir /root/.
* Enjoy

If, once rebooted, the OvS bridge hasn't set itself up correctly (check with ovs-vsctl show), run the following commands:
```bash
ovs-vsctl add-br [bridge name]
ovs-vsctl add-port [bridge name] [port/iface name]
reboot
```
This should hopefully fix the problem.

To check if xen installed correctly, run [xl list] as root and you should get an output showing Domain 0.

For more information, follow this [blog post](https://clickosblog.wordpress.com/2018/08/24/installing-clickos-for-xen-hypervisor/).