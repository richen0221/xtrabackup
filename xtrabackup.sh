#!/bin/bash
######################################################################################
# This script is for Xtrabackup tool backup and restore.                             #
# Please install the Xtrabackup and setup the proper DB persmiison on your database. #
# For further information please refer the Xtrabackup official site.                 #
# https://www.percona.com/doc/percona-xtrabackup/LATEST/index.html                   #
######################################################################################
# Author: Ricky Chen        richen0221@gmail.com                     Ver. 180122     #
######################################################################################
# Usage :                                                                            #
# Please enter the arguments as below:                                               #
# -b or --backup for backup                                                          #
# -r 20180101 or --restore 20180101 for restore                                      #
# -k 30 or --housekeeper 30 to cleanup the greater 30 days old backups               #
######################################################################################

### Variables area ### please keep the "/" in the end of directory variable
BASEDIR=/home/backupdb/
MYSQL_DIR=/home/mysql/
DB_USER=backup
DB_PASSWORD=backup!@#

### Don't modify the below of codes ###
DATE=`date +"%Y%m%d"`
BACKDIR=$BASEDIR$DATE
LOG_PATH=/var/log/xtrabackup.log
TIME_STAMP=`date "+%Y-%m-%d %H:%M:%S"`
GZIP=-9

function backup {
        echo "$TIME_STAMP ============================== Create the $BASEDIR directory =============================="
        /bin/mkdir -p $BACKDIR
        
        echo "$TIME_STAMP ============================== Backing up the DB to $BACKDIR =============================="
        /bin/xtrabackup --user=$DB_USER --password=$DB_PASSWORD --backup --target-dir=$BACKDIR/xtradbbk
        # comment it if don't need the mysqldump function
        # /bin/mysqldump -uroot --all-databases > $BACKDIR/All-DBs-backup-$DATE.sql
        
        echo "$TIME_STAMP ============================== Clean up the backup folder and tar the backup files =============================="
        cd $BASEDIR && /bin/tar zcvf $DATE.tgz $DATE && /bin/rm -fr $BACKDIR
        }

function restore {
        echo "$TIME_STAMP ============================== Enter the $BASEDIR =============================="
        cd $BASEDIR
        
        if [[ -s $BASEDIR$RESTORE_DATE.tgz ]]; then
            echo "$TIME_STAMP ============================== Untar the backup file $RESTORE_DATE.tgz =============================="
            tar zxvf $RESTORE_DATE.tgz
        
            echo "$TIME_STAMP ============================== Use the xtrabackup prepare file =============================="
            xtrabackup --prepare --target-dir=$BASEDIR/$RESTORE_DATE/xtradbbk
            
            echo "$TIME_STAMP ============================== Stop the mariadb service =============================="
            systemctl stop mariadb.service
            
            echo "$TIME_STAMP ============================== Delete the MySQL files =============================="
            rm -fr $MYSQL_DIR*
            
            echo "$TIME_STAMP ============================== Roll back the backup files =============================="
            xtrabackup --copy-back --target-dir=$BASEDIR/$RESTORE_DATE/xtradbbk
            
            echo "$TIME_STAMP ============================== Change the files' permission =============================="
            chown mysql.mysql -R $MYSQL_DIR
            
            echo "$TIME_STAMP ============================== Start the mariadb service =============================="
            systemctl start mariadb.service
        else
            echo "$TIME_STAMP ============================== $BASEDIR$RESTORE_DATE.tgz is not exisiting =============================="
        fi
        }

function housekeeper {
        find $BASEDIR -mtime +$KEEP_DAYS -exec rm -fr {} \;
        }

case "$1" in
    -b|--backup)
    printf "Backup the database......
            Please refer the log in $LOG_PATH \n"
    backup >> $LOG_PATH 2>&1
    ;;
    
    -r|--restore)
    RESTORE_DATE="$2"
        if [ ! -z "$RESTORE_DATE" ] ; then
            echo "Starting to restore the database...."
            restore
        else
            echo "Please provide the restore date string in the $BASEDIR. like '20180101'"
        fi    
    ;;
    
    -k|--housekeeper)
    KEEP_DAYS="$2"
        if [ ! -z "$KEEP_DAYS" ] ; then
            echo "Starting to cleanup the backups...."
            housekeeper
        else
            echo "Please provide the keep days. like '30' to cleanup the greater 30 days old backups."
        fi
    ;;
    
    *) printf "Please enter the arguments as below:
             '-b' or '--backup' for backup
             '-r 20180101' or '--restore 20180101' for restore 
             '-k 30' or '--housekeeper 30' to cleanup the greater 30 days old backups \n"
esac
