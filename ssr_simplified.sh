#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Simplified ShadowsocksR server installer
#	Version: 3.0.0-simplified
#	Fixed: rc4-md5 encryption, origin protocol, plain obfs, BBR only
#=================================================

sh_ver="3.0.0-simplified"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
ssr_folder="/usr/local/shadowsocksr"
ssr_ss_file="${ssr_folder}/shadowsocks"
config_user_file="${ssr_folder}/config.json"
ssr_log_file="${ssr_ss_file}/ssserver.log"
BBR_file="${file}/bbr.sh"
jq_file="${ssr_folder}/jq"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Separator_1="——————————————————————————————"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${Green_background_prefix} sudo su ${Font_color_suffix}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
SSR_installation_status(){
	[[ ! -e ${config_user_file} ]] && echo -e "${Error} 没有发现 ShadowsocksR 配置文件，请检查 !" && exit 1
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} 没有发现 ShadowsocksR 文件夹，请检查 !" && exit 1
}
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} 没有发现 BBR脚本，开始下载..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh; then
			echo -e "${Error} BBR 脚本下载失败 !" && exit 1
		else
			echo -e "${Info} BBR 脚本下载完成 !"
			chmod +x bbr.sh
		fi
	fi
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Get_User(){
	[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ解析器 不存在，请检查 !" && exit 1
	port=`${jq_file} '.server_port' ${config_user_file}`
	password=`${jq_file} '.password' ${config_user_file} | sed 's/^.//;s/.$//'`
	method=`${jq_file} '.method' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol=`${jq_file} '.protocol' ${config_user_file} | sed 's/^.//;s/.$//'`
	obfs=`${jq_file} '.obfs' ${config_user_file} | sed 's/^.//;s/.$//'`
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
ss_link_qr(){
	SSbase64=$(urlsafe_base64 "${method}:${password}@${ip}:${port}")
	SSurl="ss://${SSbase64}"
	SSQRcode="http://doub.pw/qr/qr.php?text=${SSurl}"
	ss_link=" SS链接: ${Green_font_prefix}${SSurl}${Font_color_suffix} \n SS二维码: ${Green_font_prefix}${SSQRcode}${Font_color_suffix}"
}
View_User(){
	SSR_installation_status
	Get_IP
	Get_User
	ss_link_qr
	clear && echo "===================================================" && echo
	echo -e " ShadowsocksR 配置信息：" && echo
	echo -e " IP地址 : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " 端口   : ${Green_font_prefix}${port}${Font_color_suffix}"
	echo -e " 密码   : ${Green_font_prefix}${password}${Font_color_suffix}"
	echo -e " 加密   : ${Green_font_prefix}${method}${Font_color_suffix}"
	echo -e " 协议   : ${Green_font_prefix}${protocol}${Font_color_suffix}"
	echo -e " 混淆   : ${Green_font_prefix}${obfs}${Font_color_suffix}"
	echo -e "${ss_link}"
	echo -e " ${Green_font_prefix}提示: ${Font_color_suffix}在浏览器中打开二维码链接即可查看。"
	echo && echo "==================================================="
}
Set_config_port(){
	while true
	do
	echo -e "请输入要设置的ShadowsocksR账号 端口"
	read -e -p "(默认: 8388):" ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="8388"
	echo $((${ssr_port}+0)) &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_port} -ge 1 ]] && [[ ${ssr_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	端口 : ${Green_font_prefix}${ssr_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} 请输入正确的数字(1-65535)"
		fi
	else
		echo -e "${Error} 请输入正确的数字(1-65535)"
	fi
	done
}
Set_config_password(){
	echo "请输入要设置的ShadowsocksR账号 密码"
	read -e -p "(默认: password123):" ssr_password
	[[ -z "${ssr_password}" ]] && ssr_password="password123"
	echo && echo ${Separator_1} && echo -e "	密码 : ${Green_font_prefix}${ssr_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_all(){
	Set_config_port
	Set_config_password
	ssr_method="rc4-md5"
	ssr_protocol="origin"
	ssr_obfs="plain"
	echo && echo ${Separator_1}
	echo -e "	加密 : ${Green_font_prefix}${ssr_method}${Font_color_suffix} (固定)"
	echo -e "	协议 : ${Green_font_prefix}${ssr_protocol}${Font_color_suffix} (固定)"
	echo -e "	混淆 : ${Green_font_prefix}${ssr_obfs}${Font_color_suffix} (固定)"
	echo ${Separator_1} && echo
}
Modify_config_port(){
	SSR_installation_status
	Set_config_port
	port=`${jq_file} '.server_port' ${config_user_file}`
	Del_iptables
	Write_configuration
	Add_iptables
	Save_iptables
	Restart_SSR
}
Modify_config_password(){
	SSR_installation_status
	Set_config_password
	Write_configuration
	Restart_SSR
}
Modify_config_all(){
	SSR_installation_status
	Get_User
	Set_config_all
	port=`${jq_file} '.server_port' ${config_user_file}`
	Del_iptables
	Write_configuration
	Add_iptables
	Save_iptables
	Restart_SSR
}
Write_configuration(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${ssr_port},
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "password": "${ssr_password}",
    "timeout": 120,
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "redirect": "",
    "dns_ipv6": false,
    "fast_open": false,
    "workers": 1
}
EOF
}
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} 没有安装Python，开始安装..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python
		else
			apt-get install -y python
		fi
	fi
}
Centos_yum(){
	yum update
	cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
	if [[ $? = 0 ]]; then
		yum install -y vim unzip crond net-tools
	else
		yum install -y vim unzip crond
	fi
}
Debian_apt(){
	apt-get update
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y vim unzip cron net-tools
	else
		apt-get install -y vim unzip cron
	fi
}
Download_SSR(){
	cd "/usr/local"
	wget -N --no-check-certificate "https://github.com/ToyoDAdoubi/shadowsocksr/archive/manyuser.zip"
	[[ ! -e "manyuser.zip" ]] && echo -e "${Error} ShadowsocksR 下载失败 !" && exit 1
	unzip -q manyuser.zip
	[[ ! -e "/usr/local/shadowsocksr-manyuser/" ]] && echo -e "${Error} ShadowsocksR 解压失败 !" && rm -rf manyuser.zip && exit 1
	mv "/usr/local/shadowsocksr-manyuser/" "${ssr_folder}"
	[[ ! -e "${ssr_folder}/" ]] && echo -e "${Error} ShadowsocksR 文件夹重命名失败 !" && rm -rf manyuser.zip && rm -rf "/usr/local/shadowsocksr-manyuser/" && exit 1
	rm -rf manyuser.zip
	cd "${ssr_folder}"
	bash setup.sh install
	[[ ! -e "${ssr_folder}/server.py" ]] && echo -e "${Error} ShadowsocksR 安装失败 !" && exit 1
	echo -e "${Info} ShadowsocksR 下载安装完成！"
}
Service_SSR(){
	if [[ ${release} = "centos" ]]; then
		wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/service/ssr_centos -O /etc/init.d/ssr
		chmod +x /etc/init.d/ssr
		chkconfig --add ssr
		chkconfig ssr on
	else
		wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/service/ssr_debian -O /etc/init.d/ssr
		chmod +x /etc/init.d/ssr
		update-rc.d -f ssr defaults
	fi
	echo -e "${Info} ShadowsocksR 服务管理脚本下载完成 !"
}
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		cd "${ssr_folder}"
		if [[ ${bit} = "x86_64" ]]; then
			wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" -O ${jq_file}
		else
			wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32" -O ${jq_file}
		fi
		[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ解析器 下载失败，请检查 !" && exit 1
		chmod +x ${jq_file}
		echo -e "${Info} JQ解析器 下载安装完成，继续..."
	else
		echo -e "${Info} JQ解析器 已安装，继续..."
	fi
}
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	Check_python
	JQ_install
}
Install_SSR(){
	check_root
	[[ -e ${config_user_file} ]] && echo -e "${Error} 检测到 ShadowsocksR 已安装，请检查 !" && exit 1
	echo -e "${Info} 开始安装依赖..."
	Installation_dependency
	echo -e "${Info} 开始下载/安装..."
	Download_SSR
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_SSR
	echo -e "${Info} 开始设置账号配置..."
	Set_config_all
	Write_configuration
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	Add_iptables
	Save_iptables
	echo -e "${Info} 开始启动 ShadowsocksR..."
	Start_SSR
	echo && echo "===================================================" && echo
	echo -e "${Info} ShadowsocksR 安装完成！"
	View_User
}
Update_SSR(){
	SSR_installation_status
	cd ${ssr_folder}
	git pull
	Restart_SSR
}
Uninstall_SSR(){
	SSR_installation_status
	echo "确定要 卸载 ShadowsocksR？[y/N]" && echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		port=`${jq_file} '.server_port' ${config_user_file}`
		Del_iptables
		Save_iptables
		if [[ ${release} = "centos" ]]; then
			chkconfig --del ssr
		else
			update-rc.d -f ssr remove
		fi
		rm -rf ${ssr_folder} && rm -rf /etc/init.d/ssr
		echo && echo " ShadowsocksR 卸载完成 !" && echo
	else
		echo && echo " 卸载已取消..." && echo
	fi
}
View_user_connection_info(){
	SSR_installation_status
	IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
	echo -e "当前连接总数: ${Green_font_prefix}"${IP_total}"${Font_color_suffix}"
	IP_list=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
	if [[ -z ${IP_list} ]]; then
		echo -e "当前没有连接！"
	else
		echo -e "当前连接IP: \n${Green_font_prefix}${IP_list}${Font_color_suffix}\n"
	fi
}
Modify_Config(){
	SSR_installation_status
	echo && echo -e "你要做什么？
 ${Green_font_prefix}1.${Font_color_suffix} 修改 端口
 ${Green_font_prefix}2.${Font_color_suffix} 修改 密码
 ${Green_font_prefix}3.${Font_color_suffix} 修改 全部配置
 ${Tip} 加密: rc4-md5 / 协议: origin / 混淆: plain (固定)" && echo
	read -e -p "(默认: 取消):" modify_num
	[[ -z "${modify_num}" ]] && echo -e "已取消..." && exit 1
	if [[ ${modify_num} == "1" ]]; then
		Modify_config_port
	elif [[ ${modify_num} == "2" ]]; then
		Modify_config_password
	elif [[ ${modify_num} == "3" ]]; then
		Modify_config_all
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z "${PID}" ]] && echo -e "${Error} ShadowsocksR 正在运行，请检查 !" && exit 1
	/etc/init.d/ssr start
}
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z "${PID}" ]] && echo -e "${Error} ShadowsocksR 没有运行，请检查 !" && exit 1
	/etc/init.d/ssr stop
}
Restart_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z "${PID}" ]] && /etc/init.d/ssr stop
	/etc/init.d/ssr start
}
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo
	tail -f ${ssr_log_file}
}
Configure_BBR(){
	echo && echo -e "  你要做什么？

  ${Green_font_prefix}1.${Font_color_suffix} 安装 BBR
  ${Green_font_prefix}2.${Font_color_suffix} 启动 BBR
  ${Green_font_prefix}3.${Font_color_suffix} 停止 BBR
  ${Green_font_prefix}4.${Font_color_suffix} 查看 BBR 状态" && echo
	read -e -p "(默认: 取消):" bbr_num
	[[ -z "${bbr_num}" ]] && echo "已取消..." && exit 1
	if [[ ${bbr_num} == "1" ]]; then
		Install_BBR
	elif [[ ${bbr_num} == "2" ]]; then
		Start_BBR
	elif [[ ${bbr_num} == "3" ]]; then
		Stop_BBR
	elif [[ ${bbr_num} == "4" ]]; then
		Status_BBR
	else
		echo -e "${Error} 请输入正确的数字 [1-4]" && exit 1
	fi
}
Install_BBR(){
	BBR_installation_status
	bash "${BBR_file}"
}
Start_BBR(){
	BBR_installation_status
	bash "${BBR_file}" start
}
Stop_BBR(){
	BBR_installation_status
	bash "${BBR_file}" stop
}
Status_BBR(){
	BBR_installation_status
	bash "${BBR_file}" status
}
menu_status(){
	if [[ -e ${config_user_file} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
		else
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
		fi
	else
		echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
	fi
}

check_root
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1

echo -e "  ShadowsocksR 简化版一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- 固定配置: rc4-md5 / origin / plain ----

  ${Green_font_prefix}1.${Font_color_suffix} 安装 ShadowsocksR
  ${Green_font_prefix}2.${Font_color_suffix} 更新 ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix} 卸载 ShadowsocksR
————————————
  ${Green_font_prefix}4.${Font_color_suffix} 查看 账号信息
  ${Green_font_prefix}5.${Font_color_suffix} 显示 连接信息
  ${Green_font_prefix}6.${Font_color_suffix} 修改 配置
————————————
  ${Green_font_prefix}7.${Font_color_suffix} 启动 ShadowsocksR
  ${Green_font_prefix}8.${Font_color_suffix} 停止 ShadowsocksR
  ${Green_font_prefix}9.${Font_color_suffix} 重启 ShadowsocksR
 ${Green_font_prefix}10.${Font_color_suffix} 查看 日志
————————————
 ${Green_font_prefix}11.${Font_color_suffix} 配置 BBR
  "
menu_status
echo && read -e -p "请输入数字 [1-11]：" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Update_SSR
	;;
	3)
	Uninstall_SSR
	;;
	4)
	View_User
	;;
	5)
	View_user_connection_info
	;;
	6)
	Modify_Config
	;;
	7)
	Start_SSR
	;;
	8)
	Stop_SSR
	;;
	9)
	Restart_SSR
	;;
	10)
	View_Log
	;;
	11)
	Configure_BBR
	;;
	*)
	echo -e "${Error} 请输入正确的数字 [1-11]"
	;;
esac
