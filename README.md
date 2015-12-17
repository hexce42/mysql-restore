# mysql-restore

##Description
Puppet module for sql file restore on mysql server, it can restore a local or remote(via ssh) file either compressed or non-compressed.

##Provides
*`mysql-restore::sqlfile` resource for sql file restore
*`mysql_integrity` custom fact for tablespace integrity check

### mysql-restore::sqlfile

#### Functioning
In case of local file, the resource check if a hash of the file is already stored in the work directroy, and if that hash is identical with the data hash of the file. If the hashes are match, the resource do not process the file. When the hashes are not matched the sql file is moved to the work directory, and restored to the server. After the restore a hash is generated from the first 1Mbyte of the file, and saved in the work directory. When the has generation also finished the work directory file is deleted.

In case of remote file the process is similar, logs into the remote host through ssh with the given user (public key autenticatin should be set up), check the file based on hash, and if no match downloads it to the work directory for restore. 


#### Parameters

##### `mysql-restore::sqlfile`

##### `filename`
The relative filename of the file to be restored. Defaults to the name of the resource.

##### `filepath`
The path of the file to be restored.

##### `remotehost`
The host where the file should be restored, only used if declaring an exported resource, the destination host could be picking it up based on this attribute.

##### `workdir`
The directroy where the sql file is moved for restore, plus where the sql file hash is stored. Default /tmp

##### `sourcehost`
The host where from the sql file should be copied over

##### `sshuser`
User on the source host with access to the sql file.

##### `sshport`
SSH port number, default 22.

##### `restoreuser` , `restorepassword`
Username and password for the Mysql user to apply restores, in case of full server restore usually the.

##### `compressed`
Define if the sql file is compressed. Possible values are 'bzip','gzip','none'. Default is 'none'. 

#### Usage

##### Local Restore
Definie the resource in the node manifest the following way:

~~~
mysql-restore::sqlfile {'restore.bz2':
        filepath => '/var/lib/mysql/backups',
        compressed => 'bzip',
        restoreuser => 'root',
        restorepasswd => 'password',
}
~~~

At next puppet run, the /var/lib/mysql/backup/restore.bz2 sqlfile will be uploaded to the local server and a has generated, so no restore occur in the following runs.

##### Restore form remote host
Define in the node manifest

~~~
mysql-restore::sqlfile {'restore.bz2':
        filepath => '/var/lib/mysql/backups',
        compressed => 'bzip',
        sshuser => 'backup',
        sshport => '222',
        restoreuser => 'root',
        restorepasswd => 'password',
        sourcehost => 't-mysql.lab',
    }
~~~
At nex puppet run, the /var/lib/mysql/backup/restore.bz2 will be downloaded from t-mysq.lab and uploaded to the local mysl server and a hash generated so not upload occur in the following runs.

##### Disaster Recovery Server
We have two mysql servers t-mysql.lab and t-mysql-drs.lab both managed by the puppet mysql module. We run full server backups on t-mysql.lab and want does backup to be autmaticaly uploaded to t-mysql-drs.lab

In the t-mysql.lab node manifest we define the backup the following way:
~~~
class {'::mysql::server::backup':
        backupuser => 'backup',
        backuppassword => 'backup',
        backupdir => '/var/lib/mysql/backups',
        backupdirowner => 'backup',
        backupdirgroup => 'backup',
        backuprotate => '5',
        postscript => 'rm -f /var/lib/mysql/backups/latest.bz2 ; ln -s `ls -lAtr /var/lib/mysql/backups/*.bz2 | tail -1 | awk \'{print $9}\'` /var/lib/mysql/backups/latest.bz2',
        time => ['01','00'],
    }
~~~
The backup runs every day at 1:00AM and cretes an sql file in the /var/lib/mysql/backups directory. The postscrip after every run creates a symbolic link named latest.bz2 to the latest sql file.

In t-mysql-drs.lab node manifest the following needs to be set
~~~
mysql-restore::sqlfile {'latest.bz2':
        filepath => '/var/lib/mysql/backups',
        compressed => 'bzip',
        sshuser => 'backup',
        sshport => '222',
        restoreuser => 'root',
        restorepasswd => 'password',
        sourcehost => 't-mysql.lab',
    }
~~~
This way the resource checking the /var/lib/mysql/backups/latest.bz2 at every puppet run on t-mysql.lab, if the hash is not matched with the one saved in the pervious one ( so the file changed) then uploads the new file to the mysql server and saves the hash.

### mysql_integrity

Is a custom fact, that runs the following querry on the mysql server:
~~~
echo "select concat(\"check table \",table_schema,\".\",table_name,\";\") from information_schema.tables" | mysql -N| mysql -N | grep error 
~~~

It checks all the tables in the server, and if find errors then set its value to 'false' otherwise 'true'

#### Usage
It can be used to trigger for example a table repair or a restore
~~~
if $mysql_integrity == 'false' {
    mysql-restore::sqlfile {'latest.bz2':
        filepath => '/var/lib/mysql/backups',
        compressed => 'bzip',
        restoreuser => 'root',
        restorepasswd => 'password',
   }
}
~~~

