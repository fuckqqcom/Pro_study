#!/bin/bash

declare -a sources
declare -a targets
declare packagelog

LOG_DIR=/var/fuwushe/log/update
LOG_FILE=update.log
MYSQL_FILE=mysql-5.2.0-falcon-alpha-linux-x86_64-glibc23.tar.gz
MYSQL_NAME=mysql-5.2.0-falcon-alpha-linux-x86_64-glibc23
JDK_FILE=jdk-7-linux-x64.tar.gz
JDK_PREFILE=libstdc.zip
JDK_NAME=jdk1.7.0
SYSTEM_PATH=/usr/local/fuwushe
MYSQL_PASSWORD=3.1415926535
HIBERNATE_FILE=/WEB-INF/classes/hibernate.properties
SUM_FILE=/WEB-INF/classes/conf/sum.properties
SLAVE_FILE=/WEB-INF/classes/conf/slave.properties
PACKAGE_FILE=F16.2_ad0_Linux64.zip

log_upgrade_ok() {
	#判断函数参数个数 
	if [ $# -lt 2 ] ; then                  
		return          
	fi

	echo $1 Upgrade Successful $2 >> $LOG_DIR/$LOG_FILE
}

log_upgrade_fail() {
	#判断函数参数个数 
	if [ $# -lt 2 ] ; then                  
		return          
	fi

	echo $1 Upgrade Failed $2 >> $LOG_DIR/$LOG_FILE
}

log_msg_file() {
	#判断函数参数个数 
	if [ $# -lt 2 ] ; then                  
		return          
	fi
	
	path=$LOG_DIR/$1
	if [ ! -d $path ]; then
		mkdir -p $path
	fi
	
	packagelog=$path/$2.log
}

# 必须先调用log_msg_file设置日志文件
log_msg() {
	declare i
#判断函数参数个数 
	if [ $# -lt 1 ] ; then                  
		return          
	fi

	for i
	do
		echo $i >> $packagelog
	done
}

java_update_security(){
	log_msg "update jdk security"
	$SYSTEM_PATH/jre/bin/java -version 2>/tmp/version.txt
	ret=$?
	cat /tmp/version.txt |grep -q "1.7"
	if [ "$ret" = "0" ]; then
		log_msg "jdk 1.7 copy jar";
		/bin/cp -a $SYSTEM_PATH/update/java7/jre/lib/security/* $SYSTEM_PATH/jre/lib/security/
	else
		log_msg "jdk 1.6 copy jar";
		/bin/cp -a $SYSTEM_PATH/update/java6/jre/lib/security/* $SYSTEM_PATH/jre/lib/security/
	fi
	rm -rf /tmp/version.txt
	log_msg "update jdk security end";
}

mysql_install(){
	if [ ! -d "$SYSTEM_PATH" ]; then
		log_msg "ERROR: fuwushe path $SYSTEM_PATH not existed, exit!";
		exit 1;
	fi
	
	cd $SYSTEM_PATH
	
	groupadd mysql
	useradd mysql -g mysql
	if [ "$?" != "0" ]; then
		log_msg "ERROR: Add mysql user error, exit!";
		exit 1;
	fi
	
	if [ ! -f "$SYSTEM_PATH/$MYSQL_FILE" ]; then
		log_msg "ERROR: $SYSTEM_PATH/$MYSQL_FILE file not existed, exit!";
		exit 1;
	else
		log_msg "tar zxvf $SYSTEM_PATH/$MYSQL_FILE"
		tar zxvf $SYSTEM_PATH/$MYSQL_FILE >> $packagelog;
		
		log_msg "ln $MYSQL_NAME mysql";
		ln -s $MYSQL_NAME mysql;
		
		log_msg "ln -s $SYSTEM_PATH/mysql /usr/local/mysql";
		ln -s $SYSTEM_PATH/mysql /usr/local/mysql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: ln mysql error, error code $?";
			exit $?;
		fi
		
		chown -R mysql:mysql /var/lib/mysql
	fi
	
}

mysql_config(){
	cd $SYSTEM_PATH/mysql
	
	log_msg "chown and chgrp mysql";
	chown -R mysql .;
	chgrp -R mysql .;
	
	log_msg "chmod bin and scripts/mysql_install_db";
	chmod +x ./bin/*.*;
	chmod +x ./scripts/mysql_install_db;
	./scripts/mysql_install_db --user=mysql;
	
	log_msg "chown root and mysql user";
	chown -R root .;
	chown -R mysql data/;
	
	log_msg "cp /etc/init.d/mysqld";
	cp $SYSTEM_PATH/mysql/support-files/mysql.server /etc/rc.d/init.d/mysqld;
	
	log_msg "chmod myslqd";
	chmod 755 /etc/rc.d/init.d/mysqld
	
	log_msg "chkconfig --add mysqld";
	chkconfig --add mysqld;
	
	log_msg "cp my.cnf";
	cp $SYSTEM_PATH/mysql/support-files/my-medium.cnf /etc/my.cnf
	
	log_msg "default-character-set=utf8 my.cnf";
	sed -i 's/^\(\[mysqld\]\)$/\1\ndefault-character-set=utf8/' /etc/my.cnf
	
	log_msg "/tmp/mysql.sock config"
	sed -i '/^socket/s/\/tmp\/mysql.sock/\/var\/lib\/mysql\/mysql.sock/' /etc/my.cnf
	
	log_msg "./scripts/mysql_install_db --user=mysql"
	./scripts/mysql_install_db --user=mysql
	
	log_msg "mysqld start";
	/etc/rc.d/init.d/mysqld start
	
	
	$SYSTEM_PATH/mysql/bin/mysqladmin -u root password $MYSQL_PASSWORD
	if [ "$?" != "0" ]; then
		log_msg "ERROR: mysql start error, exit!";
		exit $?;
	fi	
}

mysql_import(){
		log_msg "import mysql stfoa.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/stfoa.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_ccb.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_ccb.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl_dc.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl_dc.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl_so.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl_so.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl_so_sale.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl_so_sale.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl_so_stocktake.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl_so_stocktake.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_dl_so_sum.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_dl_so_sum.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_fcb.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_fcb.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql biz_frm.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/biz_frm.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
		
		log_msg "import mysql proc.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD mysql <$SYSTEM_PATH/db/proc.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import proc error $?, exit!";
			exit $?;
		fi
}

mysql_import_single(){
		log_msg "import mysql $1.sql"
		$SYSTEM_PATH/mysql/bin/mysql -uroot -p$MYSQL_PASSWORD <$SYSTEM_PATH/db/$1.sql
		if [ "$?" != "0" ]; then
			log_msg "ERROR: mysql import setup error $?, exit!";
			exit $?;
		fi
}

mysql_prepare(){
	log_msg "install libstdc.zip"
	cd $SYSTEM_PATH;
	
	if [ ! -f "$JDK_PREFILE" ]; then
		log_msg "ERROR: $JDK_PREFILE is not exist, exit!"
		exit 1;
	fi
	
	unzip $JDK_PREFILE >> $packagelog;
	rpm -ivh libstdc64.rpm >> $packagelog; 
	if [ "$?" != "0" ]; then
			log_msg "ERROR: install libstdc64.rpm error $?, exit!";
			exit $?;
	fi
}


jdk_install(){
	log_msg "install jdk";
	cd $SYSTEM_PATH;
	
	tar xvf $JDK_FILE >> $packagelog
	ln -s $JDK_NAME jdk
	ln -s jdk/jre jre
	if [ "$?" != "0" ]; then
		log_msg "ERROR: jdk install error, exit!";
		exit $?;
	fi	
}

jdk_config(){
	cat /etc/profile | grep JAVA_HOME
	if [ "$?" != "0" ]; then
			log_msg "config JAVA_HOME $SYSTEM_PATH/jdk";
			echo "JAVA_HOME=$SYSTEM_PATH/jdk" >> /etc/profile
	fi
	
	cat /etc/profile | grep JRE_HOME
	if [ "$?" != "0" ]; then
			echo "JRE_HOME=$SYSTEM_PATH/jre" >> /etc/profile
	fi
	
	cat /etc/profile | grep PATH
	if [ "$?" != "0" ]; then
			echo "PATH=$PATH:$JAVA_HOME/bin:JRE_HOME/bin" >> /etc/profile
	fi
	
	cat /etc/profile | grep CLASSPATH
	if [ "$?" != "0" ]; then
			echo "CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib:" >> /etc/profile
	fi
	
	cat /etc/profile | grep tomcat_HOME
	if [ "$?" != "0" ]; then
			echo "tomcat_HOME=$SYSTEM_PATH/tomcat" >> /etc/profile
			echo "export JAVA_HOME JRE_HOME PATH CLASSPATH tomcat_HOME" >> /etc/profile
	fi
	
	sleep 3
	
	cat /etc/rc.d/rc.local | grep /etc/profile
	if [ "$?" != "0" ]; then
			echo "source /etc/profile" >> /etc/rc.d/rc.local
	fi
	
	cat /etc/profile | grep tomcat/bin/startup.sh
	if [ "$?" != "0" ]; then
			echo "$SYSTEM_PATH/tomcat/bin/startup.sh" >> /etc/rc.d/rc.local
	fi
	
	chmod 755 /etc/rc.d/rc.local
}

tomcat_config(){
	#cc
	log_msg "config cc"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/cc/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/cc/$HIBERNATE_FILE
	#oa
	log_msg "config oa"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/oa/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/oa/$HIBERNATE_FILE
	#hr
	log_msg "config hr"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/hr/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/hr/$HIBERNATE_FILE
	#tc
	log_msg "config tc"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/tc/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/tc/$HIBERNATE_FILE
	#pb
	log_msg "config pb"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/pb/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/pb/$HIBERNATE_FILE
	#fm
	log_msg "config fm"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/fm/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/fm/$HIBERNATE_FILE
	#crm
	log_msg "config crm"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/crm/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/crm/$HIBERNATE_FILE
	#dlm
	log_msg "config dlm"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/dlm/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dlm/$HIBERNATE_FILE
	#dls
	log_msg "config dls"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/dls/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dls/$HIBERNATE_FILE
	#dlmpda
	log_msg "config dlmpda"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/dlmpda/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dlmpda/$HIBERNATE_FILE
	#dlspda
	log_msg "config dlspda"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/dlspda/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dlspda/$HIBERNATE_FILE
	#ccb
	log_msg "config ccb"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/ccb/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/ccb/$HIBERNATE_FILE
	#dls
	log_msg "config sum"
	sed -i 's#sum.url = jdbc:mysql://localhost:13306/biz_dl_so_sum#sum.url = jdbc:mysql://localhost:3306/biz_dl_so_sum\n#' $SYSTEM_PATH/tomcat/webapps/dls/$SUM_FILE
	sed -i 's#sum.password = 3.1415926#sum.password = 3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dls/$SUM_FILE
	#dlm
	log_msg "config slave"
	sed -i 's#slave.url = jdbc:mysql://localhost:13306/stfoa#slave.url = jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/dlm/$SLAVE_FILE
	sed -i 's#slave.password = 3.1415926#slave.password = 3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/dlm/$SLAVE_FILE
}

tomcat_config_rds(){
	log_msg "config $1"
	sed -i 's/localhost/'$2'/g' $SYSTEM_PATH/tomcat/webapps/$1/$HIBERNATE_FILE
	sed -i 's/root/'$3'/g' $SYSTEM_PATH/tomcat/webapps/$1/$HIBERNATE_FILE
	sed -i 's/3.1415926535/'$4'/g' $SYSTEM_PATH/tomcat/webapps/$1/$HIBERNATE_FILE
}

tomcat_config_single(){
	log_msg "config $1"
	sed -i 's#hibernate.connection.url=jdbc:mysql://localhost:13306/stfoa#hibernate.connection.url=jdbc:mysql://localhost:3306/stfoa\n#' $SYSTEM_PATH/tomcat/webapps/$1/$HIBERNATE_FILE
	sed -i 's#hibernate.connection.password=3.1415926#hibernate.connection.password=3.1415926535\n#' $SYSTEM_PATH/tomcat/webapps/$1/$HIBERNATE_FILE
}

fuwushe_install(){
	log_msg "unzip $PACKAGE_FILE"
	cd $SYSTEM_PATH
	
	if [ ! -f "$SYSTEM_PATH/$PACKAGE_FILE" ]; then
		log_msg "ERROR: $PACKAGE_FILE is not exist, exit!"
		exit 1;
	fi
	
	unzip $PACKAGE_FILE >> $packagelog
	chmod -R 755 upload
	chmod -R 755 derby
	chmod -R 755 dlsderby
}

fuwushe_start(){
	chmod -R 755 /usr/local/fuwushe/tomcat/bin
	source /etc/profile
	/usr/local/fuwushe/tomcat/bin/startup.sh
}


date=`date +%Y%m%d%H%M%S`

if [ "$1" == '' ] ; then
	PACKAGE_NAME=all_`date +%Y%m%d`
else
	PACKAGE_NAME=$1_`date +%Y%m%d`
fi

log_msg_file $PACKAGE_NAME $date

case "$1" in
	'mysql')
			mysql_install
			mysql_config
			mysql_import
		;;
	'mysql_pre')
			mysql_prepare
		;;
	'jdk')
			jdk_install
			jdk_config
		;;
	'jdk_update')
			java_update_security
		;;
	'fuwushe')
			fuwushe_install
			tomcat_config
			fuwushe_start
		;;
	'mysql_config')
			mysql_config
		;;
	'tomcat_config')
			tomcat_config
		;;
	'mysql_import_single')
			log_msg "import $2 sql"
			if [ "$2" == '' ] ; then
					echo "Usage: $0 $1 {stfoa|biz_ccb|biz_dl|biz_dl_dc|biz_dl_so|biz_dl_so_sale|biz_dl_so_stocktake|biz_dl_so_sum|biz_fcb|biz_frm}"
					exit 1
			else
					mysql_import_single	$2
			fi
		;;
	'tomcat_config_single')
			log_msg "config $2"
			if [ "$2" == '' ] ; then
					echo "Usage: $0 $1 {cc|oa|hr|tc|pb|fm|crm|dlm|dls|dlmpda|dlspda|ccb}"
					exit 1
			else
					tomcat_config_single	$2
			fi
		;;
	'tomcat_config_rds')
			log_msg "config $2"
			if [ "$2" == '' ] ; then
					echo "Usage: $0 $1 {cc|oa|hr|tc|pb|fm|crm|dlm|dls|dlmpda|dlspda|ccb}"
					exit 1
			else
					tomcat_config_rds	$2 $3 $4 $5
			fi
		;;
	'all')
			mysql_prepare
			mysql_install
			mysql_config
			
			sleep 3
			
			jdk_install
			
			fuwushe_install
			mysql_import
			jdk_config
			tomcat_config
			
			java_update_security
			
			fuwushe_start
		;;
	'no_mysql')
			
			jdk_install
			
			fuwushe_install
			jdk_config
			tomcat_config
			
			java_update_security
			
			fuwushe_start
		;;
	*)
		echo "Usage: $0 {fuwushe|jdk|mysql|jdk_update|all|mysql_pre|mysql_import_single|tomcat_config_single|tomcat_config|mysql_config|no_mysql|tomcat_config_rds}"
		exit 1
		;;
esac