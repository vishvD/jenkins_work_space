#!/bin/bash
#******************************************************************************************************
#                                                                                                     *
#                                                                                                     *
#                                                                                                     *
#******************************************************************************************************
<<cmt
vm_name=""
vm_img_path=""
qcow2_path=""
vm_ip=""
vm_ram=0
img_name=cpi_install.vdi
vm_priv_ip=""
cmt

declare -A __gDploy_cfg=( [vm_name]=""
                [vm_img_path]=""
                [qcow2_path]=""
                [img_name]="cpi_install.vdi"
                [vm_ip]=""
                [vm_ram]=0
                [vm_priv_ip]=""
                [build_no]="")

#__gDploy_cfg[img_name]="cpi_install.vdi"
qemu_img_convert_qcow2_vdi(){
#	set -x
        if [ -z ${__gDploy_cfg[qcow2_path]} ]; then
		failure_msg "[$LINENO] qcow2 image  missing"
        else
          echo "qcow2 : ${__gDploy_cfg[qcow2_path]}"
        fi
        if [ ! -f ${__gDploy_cfg[qcow2_path]} ] ; then 
		failure_msg "[$LINENO] qcow2 img can't be found at ${__gDploy_cfg[qcow2_path]}"
        fi
        echo "vm image: ${__gDploy_cfg[img_name]}"
        echo "'${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]}'"
        if [ ! -f ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]} ]; then 
        echo -e "\e[33mcreating vdi image from qcow2........ \e[0m"
	sudo chown jenkins: ${__gDploy_cfg[vm_img_path]}
	qemu-img convert -f qcow2 ${__gDploy_cfg[qcow2_path]} -O vdi ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]}
        if [ $? -ne 0 ]; then failure_msg "failed to convert qcow2-->vdi"
	else
		echo "vdi image ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]} created"
	fi
        fi
#        set +x
}
usage() { echo "Usage: $0 [-v <string>] [-p <string>] [-i <string>] [-r <integer>]" 1>&2; exit 1; }

#parse cli arguments
cli_parser(){
	while getopts ":v:p:q:i:t:r:" opt; do
		case $opt in 
		v)   #vm name
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[vm_name]=$OPTARG
		;; 
		p) #vdi image path
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[vm_img_path]=$OPTARG
		;;
		q) #qcow2 image path
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[qcow2_path]=$OPTARG
		;;
		i) #ip address
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[vm_ip]=$OPTARG
		;;
		t) #private ip address
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[vm_priv_ip]=$OPTARG
		;;
		r) #memory
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		__gDploy_cfg[vm_ram]=$((OPTARG))
		;;
		\?)
			echo "invalid opt"
			exit
		;;
esac
done
}

#dispaly failure message on console
failure_msg() {
	echo -e "\e[31m$* : exiting....."
        echo -e "\e[0m"
		exit
}

#validate CLI args
input_managr(){
        if [ -z ${__gDploy_cfg[vm_img_path]} ]; then
		failure_msg "vm image path missing"
        else
          echo -e "vm image path : \e[33m${__gDploy_cfg[vm_img_path]}\e[0m"
        fi
	if [ ! -f ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]} ] ; then 
		failure_msg "[$LINENO] vdi img can't be found at ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]}"
	fi
        if [ -z ${__gDploy_cfg[vm_name]} ]; then
		failure_msg "[$LINENO] vm name missing"
        else
          echo -e "vm name : \e[33m${__gDploy_cfg[vm_name]}\e[0m"
        fi
        if [ -z ${__gDploy_cfg[vm_ip]} ]; then
                 failure_msg "[$LINENO] vm_ip missing"
        else 
          echo -e  "vm ip address : \e[33m${__gDploy_cfg[vm_ip]}\e[0m"
        fi
        if [ -z ${__gDploy_cfg[vm_priv_ip]} ]; then
                 failure_msg "[$LINENO] vm_priv_ip missing"
        else 
          echo -e "vm private ip address : \e[33m${__gDploy_cfg[vm_priv_ip]}\e[0m"
        fi
        if [ ${__gDploy_cfg[vm_ram]} -eq 0 ] ; then
                failure_msg "[$LINENO] vm_ram missing"
        else 
          echo -e "vm memory : \e[33m${__gDploy_cfg[vm_ram]}\e[0m"
        fi
}

#	if [ $? -ne 0 ] ; then  failure_msg "[$LINENO] ip addr flush dev enp0s3"; fi
#	if [ $? -ne 0 ] ; then  failure_msg "[$LINENO] ip addr add dev enp0s3"; else echo "instller ready to use IP addr: '$vm_ip'" ;fi
#assign ip addr on enp0s9
ip_manager() {
	sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t <<EOF
        if [ -e /etc/sysconfig/network-scripts/ifcfg-enp0s3 ]; then
           sudo rm -f /etc/sysconfig/network-scripts/ifcfg-enp0s3
        fi
        echo "DEVICE=enp0s3" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "ONBOOT=yes" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "TYPE=Ethernet" | sudo tee -a  /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "IPADDR=${__gDploy_cfg[vm_ip]}|" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "PREFIX=24" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        sudo ifdown enp0s3
        sudo ifup enp0s3

        if [ -e /etc/sysconfig/network-scripts/ifcfg-enp0s9 ]; then
           sudo rm -f /etc/sysconfig/network-scripts/ifcfg-enp0s9
        fi
        echo "DEVICE=enp0s9" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "ONBOOT=yes" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "TYPE=Ethernet" | sudo tee -a  /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "IPADDR=${__gDploy_cfg[vm_priv_ip]}" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "PREFIX=24" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        sudo ifdown enp0s9
        sudo ifup enp0s9
        exit
EOF
}

_register_vm(){
	VBoxManage createvm --name ${__gDploy_cfg[vm_name]} --ostype "RedHat_64" --register
        if [ $? -ne 0 ]; then 
		failure_msg "[$LINENO] create vm failure"
        fi 
}

_storage_ctl_attch(){
	VBoxManage storagectl  ${__gDploy_cfg[vm_name]} --name "SATA Controller" --add sata --controller IntelAHCI
	if [ $? -ne 0 ]; then 
		failure_msg "[$LINENO] storagectl failure" 
	fi 
        #@ttach img path
 	VBoxManage storageattach ${__gDploy_cfg[vm_name]}  --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ${__gDploy_cfg[vm_img_path]}/${__gDploy_cfg[img_name]}
	if [ $? -ne 0 ] ; then 
		failure_msg "[$LINENO] storageattach failure" 
	fi 
}
_set_attr_vm() {
        #config memory
 	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --memory ${__gDploy_cfg[vm_ram]} --vram 128
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] modifyvm --memory ${__gDploy_cfg[vm_ram]} --vram 128" 
	fi 
        #@create a bridge n/w on eth0
	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --bridgeadapter1 eth0 
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating bridge adapter on eth0"
	fi
	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --nic1 bridged
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating bridge adapter on eth0"
	fi

        #@create a host only n/w on nic3 
	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --hostonlyadapter3 vboxnet1
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating host-only adapter on NIC3"
	fi
	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --nic3 hostonly
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating host-only adapter on NIC3"
	fi

        #@create a nat nw on nic2. do NAT port forwarding on port 2222
        VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --nic2 nat --nictype2 82540EM --cableconnected1 on
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating nat adapter on NIC2"
	fi
 	VBoxManage modifyvm ${__gDploy_cfg[vm_name]} --natpf2 "host2guest-ssh,tcp,,2222,,22"
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating nat adapter on NIC2"
	fi
}
_start_vm(){
	VBoxManage startvm ${__gDploy_cfg[vm_name]} --type separate
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed to start vm" 
	fi 

}
_pre_processng(){
        cli_parser $*
        qemu_img_convert_qcow2_vdi
        input_managr
}
#after vm init ..call ip_manage to configure
#IP address on proper interfaces 
_post_processng(){
        i=1
        echo -e "\e[33mbooting  ${__gDploy_cfg[vm_name]} ....."
        while [ $i -ne 0 ] ; do
        sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t "exit" 
        i=$?
        sleep 1
        done
        echo -e "\e[0m"
	ip_manager 
}
#main function ...everything will be start from here only
main() {
        echo -e "\e[32m-----------------------------------------------------------------------------"
        echo -e "\e[36m            nTI cONTINUOUS iNTEGRATION sERVER @deploymachine                 "
        echo -e "\e[32m-----------------------------------------------------------------------------\e[0m"
         
        _pre_processng $*
         export DISPLAY=:0.0
	 sudo xhost +local:root
	_register_vm
	_storage_ctl_attch
	_set_attr_vm
	_start_vm
        _post_processng
        echo -e "\e[32m fINISHED dEPLOY iNSTALLATION IP:\e[34m${__gDploy_cfg[vm_ip]}\e[0m"
} 
main $* 
        
